"""Point-in-time trend scoring used for live analysis and historical validation."""

from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd

from app.adaptive_model import classify_score, composite_score, load_model_state
from app.analysis import enrich_history, generate_signals
from app.sentiment import score_text


def _history_dict_from_frame(frame: pd.DataFrame) -> dict[str, Any]:
    enriched = enrich_history(frame)
    latest = enriched.iloc[-1]
    signals = generate_signals(enriched["Close"])
    rows = []
    for idx, row in enriched.iterrows():
        rows.append(
            {
                "date": idx.strftime("%Y-%m-%d"),
                "open": float(row["Open"]),
                "high": float(row["High"]),
                "low": float(row["Low"]),
                "close": float(row["Close"]),
                "volume": float(row["Volume"]),
            }
        )
    return {
        "history": rows,
        "summary": {
            "latest_close": float(latest["Close"]),
            "rsi": float(latest["RSI"]) if pd.notna(latest["RSI"]) else None,
            "sma20": float(latest["SMA20"]) if pd.notna(latest["SMA20"]) else None,
            "sma50": float(latest["SMA50"]) if pd.notna(latest["SMA50"]) else None,
            "sma200": float(latest["SMA200"]) if pd.notna(latest["SMA200"]) else None,
        },
        "signals": signals,
    }


def score_technical(history: dict[str, Any]) -> dict[str, Any]:
    signals = history.get("signals") or {}
    summary = history.get("summary") or {}
    overall = signals.get("overall", "neutral")
    score_map = {"bullish": 0.6, "neutral": 0.0, "bearish": -0.6}
    return {
        "score": score_map.get(str(overall), 0.0),
        "label": overall,
        "rsi": summary.get("rsi"),
        "ma_cross": signals.get("ma_cross"),
    }


def score_behavior(history: dict[str, Any]) -> dict[str, Any]:
    rows = history.get("history") or []
    if len(rows) < 25:
        return {"score": 0.0, "label": "neutral"}

    df = pd.DataFrame(rows)
    closes = df["close"].astype(float)
    volumes = df["volume"].astype(float)

    avg_volume = volumes.tail(20).mean()
    latest_volume = volumes.iloc[-1]
    volume_ratio = float(latest_volume / avg_volume) if avg_volume else 1.0

    score = 0.0
    if volume_ratio >= 1.5:
        score += 0.25
    elif volume_ratio <= 0.6:
        score -= 0.1

    if len(closes) >= 6 and closes.iloc[-6] != 0:
        momentum_5d = (float(closes.iloc[-1]) / float(closes.iloc[-6]) - 1) * 100
        if momentum_5d >= 3:
            score += 0.25
        elif momentum_5d <= -3:
            score -= 0.25

    recent = df.tail(10)
    pressure_scores = []
    for _, row in recent.iterrows():
        spread = row["high"] - row["low"]
        if spread <= 0:
            continue
        close_position = (row["close"] - row["low"]) / spread
        direction = 1 if row["close"] >= row["open"] else -1
        pressure_scores.append(close_position * direction)
    buy_pressure = sum(pressure_scores) / len(pressure_scores) if pressure_scores else 0.0
    if buy_pressure >= 0.25:
        score += 0.2
    elif buy_pressure <= -0.25:
        score -= 0.2

    label = "accumulation" if score >= 0.2 else "distribution" if score <= -0.2 else "neutral"
    return {"score": round(score, 3), "label": label}


def proxy_news_sentiment_from_price(frame: pd.DataFrame) -> dict[str, Any]:
    """Estimate headline tone from public price action already known at that date.

    Real historical news archives are not available in the free data layer, so this
    proxy maps recent price/volatility into the same keyword sentiment engine used
    for live headlines.
    """
    if len(frame) < 22:
        return {"score": 0.0, "label": "neutral", "headline_count": 0, "proxy": True}

    close = frame["Close"]
    ret_20 = float(close.iloc[-1] / close.iloc[-21] - 1)
    ret_5 = float(close.iloc[-1] / close.iloc[-6] - 1) if len(close) >= 6 else 0.0
    vol = float(close.pct_change().tail(20).std() or 0.0)

    if ret_20 >= 0.08:
        headline = "Shares rally to record highs on strong growth and bullish momentum"
    elif ret_20 >= 0.02:
        headline = "Stock gains as investors turn optimistic about recovery"
    elif ret_20 <= -0.08:
        headline = "Stock plunges on weak demand concerns and bearish outlook"
    elif ret_20 <= -0.02:
        headline = "Shares decline amid risk concerns and selling pressure"
    elif ret_5 >= 0.03:
        headline = "Stock rises on positive momentum"
    elif ret_5 <= -0.03:
        headline = "Stock falls on negative momentum"
    elif vol >= 0.025:
        headline = "Market volatility spikes as investors weigh crisis risks"
    else:
        headline = "Market mixed with neutral trading sentiment"

    sentiment = score_text(headline)
    return {
        "score": sentiment["score"],
        "label": sentiment["label"],
        "headline_count": 1,
        "proxy": True,
        "headline": headline,
    }


def score_news_live(news_payload: dict[str, Any]) -> dict[str, Any]:
    from app.sentiment import aggregate_sentiment

    agg = aggregate_sentiment(news_payload.get("items", []))
    return {
        "score": float(agg["score"]),
        "label": str(agg["label"]),
        "headline_count": int(agg["count"]),
        "proxy": False,
    }


def predict_from_frame(frame: pd.DataFrame, weights: dict[str, float] | None = None) -> dict[str, Any]:
    history = _history_dict_from_frame(frame)
    technical = score_technical(history)
    behavior = score_behavior(history)
    news = proxy_news_sentiment_from_price(frame)

    w = weights or load_model_state()["weights"]
    score = composite_score(technical["score"], news["score"], behavior["score"], w)
    label = classify_score(score, w.get("threshold", 0.25))

    return {
        "score": score,
        "label": label,
        "technical": technical,
        "news": news,
        "behavior": behavior,
        "component_scores": {
            "technical": technical["score"],
            "news": news["score"],
            "behavior": behavior["score"],
        },
    }


def overall_from_components(
    technical: dict[str, Any],
    news: dict[str, Any],
    behavior: dict[str, Any],
    weights: dict[str, float] | None = None,
) -> dict[str, Any]:
    w = weights or load_model_state()["weights"]
    score = composite_score(technical["score"], news["score"], behavior["score"], w)
    label = classify_score(score, w.get("threshold", 0.25))
    return {
        "score": score,
        "label": label,
        "suggested_action": "",
        "drivers": [
            {"factor": "Technical", "score": technical["score"], "label": technical.get("label", "neutral")},
            {"factor": "News", "score": news["score"], "label": news.get("label", "neutral")},
            {"factor": "Behavior", "score": behavior["score"], "label": behavior.get("label", "neutral")},
        ],
    }
