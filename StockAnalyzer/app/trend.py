"""Combined trend analysis from technicals, news sentiment, and trading behavior."""

from __future__ import annotations

from typing import Any

import pandas as pd

from app.data import get_history
from app.news import get_news
from app.sentiment import aggregate_sentiment
from app.symbols import is_hk_symbol, normalize_symbol


def _score_technical(history: dict[str, Any]) -> dict[str, Any]:
    signals = history.get("signals") or {}
    summary = history.get("summary") or {}
    overall = signals.get("overall", "neutral")

    score_map = {"bullish": 0.6, "neutral": 0.0, "bearish": -0.6}
    score = score_map.get(str(overall), 0.0)

    rsi_value = summary.get("rsi")
    notes: list[str] = []
    if rsi_value is not None:
        if rsi_value < 30:
            notes.append("RSI indicates oversold conditions")
        elif rsi_value > 70:
            notes.append("RSI indicates overbought conditions")
        else:
            notes.append(f"RSI at {rsi_value} is neutral")

    ma_cross = signals.get("ma_cross")
    if ma_cross == "bullish_cross":
        notes.append("Short-term moving average crossed above long-term (bullish)")
    elif ma_cross == "bearish_cross":
        notes.append("Short-term moving average crossed below long-term (bearish)")

    return {
        "score": score,
        "label": overall,
        "rsi": rsi_value,
        "ma_cross": ma_cross,
        "notes": notes,
    }


def _score_news(news_payload: dict[str, Any]) -> dict[str, Any]:
    agg = aggregate_sentiment(news_payload.get("items", []))
    notes: list[str] = []

    if agg["count"]:
        notes.append(
            f"News sentiment is {agg['label']} across {agg['count']} recent headlines"
        )
    else:
        notes.append("No recent headlines available")

    international = [i for i in news_payload.get("items", []) if i.get("region") != "HK"]
    hk_items = [i for i in news_payload.get("items", []) if i.get("region") == "HK"]
    if international:
        notes.append(f"{len(international)} international/global headlines tracked")
    if hk_items:
        notes.append(f"{len(hk_items)} Hong Kong-focused headlines tracked")

    return {
        "score": float(agg["score"]),
        "label": str(agg["label"]),
        "headline_count": int(agg["count"]),
        "notes": notes,
    }


def _score_behavior(history: dict[str, Any]) -> dict[str, Any]:
    rows = history.get("history") or []
    if len(rows) < 25:
        return {
            "score": 0.0,
            "label": "neutral",
            "volume_ratio": None,
            "momentum_5d": None,
            "buy_pressure": None,
            "notes": ["Insufficient history for behavior analysis"],
        }

    df = pd.DataFrame(rows)
    closes = df["close"].astype(float)
    volumes = df["volume"].astype(float)
    highs = df["high"].astype(float)
    lows = df["low"].astype(float)

    avg_volume = volumes.tail(20).mean()
    latest_volume = volumes.iloc[-1]
    volume_ratio = round(float(latest_volume / avg_volume), 2) if avg_volume else 1.0

    momentum_5d = None
    if len(closes) >= 6 and closes.iloc[-6] != 0:
        momentum_5d = round((float(closes.iloc[-1]) / float(closes.iloc[-6]) - 1) * 100, 2)

    recent = df.tail(10)
    pressure_scores = []
    for _, row in recent.iterrows():
        spread = row["high"] - row["low"]
        if spread <= 0:
            continue
        close_position = (row["close"] - row["low"]) / spread
        direction = 1 if row["close"] >= row["open"] else -1
        pressure_scores.append(close_position * direction)
    buy_pressure = round(sum(pressure_scores) / len(pressure_scores), 3) if pressure_scores else 0.0

    score = 0.0
    notes: list[str] = []

    if volume_ratio >= 1.5:
        score += 0.25
        notes.append(f"Volume spike: {volume_ratio}x the 20-day average (active trading)")
    elif volume_ratio <= 0.6:
        score -= 0.1
        notes.append("Volume is below average, suggesting weaker participation")

    if momentum_5d is not None:
        if momentum_5d >= 3:
            score += 0.25
            notes.append(f"Strong 5-day momentum: +{momentum_5d}%")
        elif momentum_5d <= -3:
            score -= 0.25
            notes.append(f"Weak 5-day momentum: {momentum_5d}%")

    if buy_pressure >= 0.25:
        score += 0.2
        notes.append("Recent sessions show buy-side pressure (closes near highs)")
    elif buy_pressure <= -0.25:
        score -= 0.2
        notes.append("Recent sessions show sell-side pressure (closes near lows)")

    if score >= 0.2:
        label = "accumulation"
    elif score <= -0.2:
        label = "distribution"
    else:
        label = "neutral"

    return {
        "score": round(score, 3),
        "label": label,
        "volume_ratio": volume_ratio,
        "momentum_5d": momentum_5d,
        "buy_pressure": buy_pressure,
        "notes": notes,
    }


def _overall_trend(technical: dict, news: dict, behavior: dict) -> dict[str, Any]:
    composite = round(
        technical["score"] * 0.4 + news["score"] * 0.35 + behavior["score"] * 0.25,
        3,
    )

    if composite >= 0.25:
        label = "bullish"
        action = "Bias toward buying on dips; confirm with volume and news flow."
    elif composite <= -0.25:
        label = "bearish"
        action = "Bias toward reducing exposure; watch for negative news confirmation."
    else:
        label = "neutral"
        action = "Wait for clearer alignment between news, price trend, and volume."

    drivers = []
    for name, block in ("Technical", technical), ("News", news), ("Behavior", behavior):
        drivers.append({"factor": name, "score": block["score"], "label": block["label"]})

    return {
        "score": composite,
        "label": label,
        "suggested_action": action,
        "drivers": drivers,
    }


def get_trend_analysis(symbol: str, period: str = "6mo") -> dict[str, Any]:
    normalized = normalize_symbol(symbol)
    history = get_history(normalized, period=period)
    news_payload = get_news(normalized)

    technical = _score_technical(history)
    news = _score_news(news_payload)
    behavior = _score_behavior(history)
    overall = _overall_trend(technical, news, behavior)

    return {
        "symbol": normalized,
        "market": "HK" if is_hk_symbol(normalized) else "US",
        "currency": "HKD" if is_hk_symbol(normalized) else "USD",
        "period": period,
        "overall": overall,
        "technical": technical,
        "news": news,
        "behavior": behavior,
        "recent_news": news_payload.get("items", [])[:6],
        "source": history.get("source", "unknown"),
    }
