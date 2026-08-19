"""Walk-forward validation of trend/news predictions against real historic prices."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import numpy as np
import pandas as pd
import yfinance as yf

from app.adaptive_model import (
    adjust_weights,
    classify_score,
    label_to_sign,
    load_model_state,
    load_validation_metrics,
    save_model_state,
    save_validation_metrics,
)
from app.history_store import get_ohlcv
from app.symbols import normalize_symbol
from app.trend_engine import predict_from_frame

FORWARD_DAYS = 22
STEP_DAYS = 21
WARMUP_DAYS = 252
RETURN_THRESHOLD = 0.02
TARGET_YEARS = 40


def fetch_max_history(symbol: str) -> pd.DataFrame | None:
    """Load the longest available daily history (target ~40 years).

    Validation prefers live Yahoo max history because bundled demo samples
    are only ~1 year long.
    """
    normalized = normalize_symbol(symbol)

    try:
        raw = yf.download(
            normalized,
            period="max",
            auto_adjust=True,
            progress=False,
            threads=False,
        )
    except Exception:
        raw = None

    if raw is not None and not raw.empty:
        df = raw.copy()
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)
        expected = ["Open", "High", "Low", "Close", "Volume"]
        if all(col in df.columns for col in expected):
            live = df[expected].sort_index()
            if len(live) >= WARMUP_DAYS + FORWARD_DAYS + 10:
                return live

    demo = get_ohlcv(symbol)
    if demo is not None and len(demo) >= WARMUP_DAYS + FORWARD_DAYS + 10:
        return demo

    return demo


def _actual_label(forward_return: float) -> str:
    if forward_return >= RETURN_THRESHOLD:
        return "bullish"
    if forward_return <= -RETURN_THRESHOLD:
        return "bearish"
    return "neutral"


def _forward_return(frame: pd.DataFrame, start_idx: int, forward_days: int = FORWARD_DAYS) -> float | None:
    end_idx = start_idx + forward_days
    if end_idx >= len(frame):
        return None
    start_price = float(frame["Close"].iloc[start_idx])
    end_price = float(frame["Close"].iloc[end_idx])
    if start_price == 0:
        return None
    return (end_price / start_price) - 1


def run_validation(
    symbol: str,
    adapt: bool = True,
    max_steps: int | None = None,
) -> dict[str, Any]:
    """Walk-forward test from earliest available history, adapting weights on mistakes."""
    normalized = normalize_symbol(symbol)
    frame = fetch_max_history(normalized)
    if frame is None or len(frame) < WARMUP_DAYS + FORWARD_DAYS + 10:
        raise ValueError(f"Insufficient history to validate {normalized}")

    cutoff = pd.Timestamp.now() - pd.DateOffset(years=TARGET_YEARS)
    index = frame.index
    if index.tz is not None:
        cutoff = cutoff.tz_localize(index.tz)
    if index.min() < cutoff:
        frame = frame[index >= cutoff]

    state = load_model_state()
    weights = state["weights"].copy()
    updates = state["updates"]

    records: list[dict[str, Any]] = []
    component_hits = {"technical": 0, "news": 0, "behavior": 0, "total": 0}
    rolling_accuracy: list[dict[str, Any]] = []

    start_idx = WARMUP_DAYS
    end_idx = len(frame) - FORWARD_DAYS - 1
    indices = list(range(start_idx, end_idx, STEP_DAYS))
    if max_steps:
        indices = indices[-max_steps:]

    correct = 0
    directional_total = 0
    news_correct = 0
    news_directional = 0

    for idx in indices:
        slice_frame = frame.iloc[: idx + 1]
        forward = _forward_return(frame, idx, FORWARD_DAYS)
        if forward is None:
            continue

        prediction = predict_from_frame(slice_frame, weights)
        predicted = prediction["label"]
        actual = _actual_label(forward)

        pred_sign = label_to_sign(predicted)
        actual_sign = label_to_sign(actual)
        hit = pred_sign == actual_sign and pred_sign != 0
        if pred_sign != 0:
            directional_total += 1
            if hit:
                correct += 1

        news_sign = label_to_sign(prediction["news"]["label"])
        if news_sign != 0:
            news_directional += 1
            if news_sign == actual_sign:
                news_correct += 1

        for key in ("technical", "news", "behavior"):
            comp_sign = label_to_sign(
                "bullish"
                if prediction["component_scores"][key] > 0.05
                else "bearish"
                if prediction["component_scores"][key] < -0.05
                else "neutral"
            )
            if comp_sign != 0 and comp_sign == actual_sign:
                component_hits[key] += 1
            if comp_sign != 0:
                component_hits["total"] += 1

        if adapt and pred_sign != 0:
            weights = adjust_weights(
                weights,
                prediction["component_scores"],
                predicted,
                actual,
                learning_rate=weights.get("learning_rate", 0.02),
            )
            if not hit:
                updates += 1

        date_str = frame.index[idx].strftime("%Y-%m-%d")
        records.append(
            {
                "date": date_str,
                "predicted": predicted,
                "actual": actual,
                "forward_return_pct": round(forward * 100, 2),
                "score": prediction["score"],
                "correct": hit,
            }
        )

        if directional_total and directional_total % 10 == 0:
            rolling_accuracy.append(
                {
                    "date": date_str,
                    "accuracy_pct": round(correct / directional_total * 100, 2),
                }
            )

    accuracy = round(correct / directional_total * 100, 2) if directional_total else 0.0
    news_accuracy = round(news_correct / news_directional * 100, 2) if news_directional else 0.0

    weight_history_entry = {
        "symbol": normalized,
        "at": datetime.now(timezone.utc).isoformat(),
        "accuracy_pct": accuracy,
        "news_accuracy_pct": news_accuracy,
        "weights": {
            "technical": weights["technical"],
            "news": weights["news"],
            "behavior": weights["behavior"],
        },
    }

    if adapt:
        existing = load_model_state()
        history = existing.get("history", []) + [weight_history_entry]
        save_model_state(weights, updates, history)

    metrics = {
        "symbol": normalized,
        "data_start": frame.index.min().strftime("%Y-%m-%d"),
        "data_end": frame.index.max().strftime("%Y-%m-%d"),
        "years_covered": round((frame.index.max() - frame.index.min()).days / 365.25, 1),
        "steps_evaluated": len(records),
        "directional_predictions": directional_total,
        "accuracy_pct": accuracy,
        "news_accuracy_pct": news_accuracy,
        "weight_updates": updates if adapt else 0,
        "final_weights": {
            "technical": weights["technical"],
            "news": weights["news"],
            "behavior": weights["behavior"],
        },
        "initial_weights": {
            "technical": state["weights"]["technical"],
            "news": state["weights"]["news"],
            "behavior": state["weights"]["behavior"],
        },
        "component_hit_rates": {
            key: round(component_hits[key] / max(component_hits["total"], 1) * 100, 2)
            for key in ("technical", "news", "behavior")
        },
        "recent_samples": records[-8:],
        "rolling_accuracy": rolling_accuracy[-30:],
        "methodology": {
            "forward_horizon_days": FORWARD_DAYS,
            "step_days": STEP_DAYS,
            "return_threshold_pct": RETURN_THRESHOLD * 100,
            "news_note": (
                "Historical news archives are unavailable for multi-decade backtests. "
                "News sentiment uses a price-action proxy fed through the same keyword engine, "
                "then weights auto-adjust when predictions miss realized returns."
            ),
        },
    }

    save_validation_metrics(metrics)
    return metrics


def run_validation_batch(symbols: list[str], adapt: bool = True) -> dict[str, Any]:
    results = []
    for symbol in symbols:
        try:
            results.append(run_validation(symbol, adapt=adapt, max_steps=120))
        except ValueError:
            continue

    if not results:
        raise ValueError("No symbols produced validation results")

    avg_accuracy = round(sum(r["accuracy_pct"] for r in results) / len(results), 2)
    return {"symbols": results, "average_accuracy_pct": avg_accuracy}
