"""Persisted adaptive weights for the trend prediction model."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

DEFAULT_WEIGHTS = {
    "technical": 0.40,
    "news": 0.35,
    "behavior": 0.25,
    "threshold": 0.25,
    "learning_rate": 0.02,
}

WEIGHTS_PATH = Path(__file__).resolve().parent.parent / "data" / "adaptive_weights.json"
METRICS_PATH = Path(__file__).resolve().parent.parent / "data" / "validation_metrics.json"


def _normalize(weights: dict[str, float]) -> dict[str, float]:
    total = weights["technical"] + weights["news"] + weights["behavior"]
    if total <= 0:
        return DEFAULT_WEIGHTS.copy()
    return {
        "technical": round(weights["technical"] / total, 4),
        "news": round(weights["news"] / total, 4),
        "behavior": round(weights["behavior"] / total, 4),
    }


def load_model_state() -> dict[str, Any]:
    if not WEIGHTS_PATH.exists():
        return {"weights": DEFAULT_WEIGHTS.copy(), "updates": 0, "history": []}

    try:
        payload = json.loads(WEIGHTS_PATH.read_text())
    except Exception:
        return {"weights": DEFAULT_WEIGHTS.copy(), "updates": 0, "history": []}

    weights = {**DEFAULT_WEIGHTS, **payload.get("weights", {})}
    weights.update(_normalize(weights))
    return {
        "weights": weights,
        "updates": payload.get("updates", 0),
        "history": payload.get("history", [])[-20:],
        "last_run": payload.get("last_run"),
    }


def save_model_state(weights: dict[str, float], updates: int, history: list[dict] | None = None) -> None:
    WEIGHTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    existing = load_model_state()
    payload = {
        "weights": _normalize(weights),
        "updates": updates,
        "history": (history or existing.get("history", []))[-50:],
        "last_run": existing.get("last_run"),
    }
    WEIGHTS_PATH.write_text(json.dumps(payload, indent=2))


def save_validation_metrics(metrics: dict[str, Any]) -> None:
    METRICS_PATH.parent.mkdir(parents=True, exist_ok=True)
    METRICS_PATH.write_text(json.dumps(metrics, indent=2))


def load_validation_metrics() -> dict[str, Any] | None:
    if not METRICS_PATH.exists():
        return None
    try:
        return json.loads(METRICS_PATH.read_text())
    except Exception:
        return None


def label_to_sign(label: str) -> int:
    if label == "bullish":
        return 1
    if label == "bearish":
        return -1
    return 0


def composite_score(technical: float, news: float, behavior: float, weights: dict[str, float] | None = None) -> float:
    w = weights or load_model_state()["weights"]
    return round(
        technical * w["technical"] + news * w["news"] + behavior * w["behavior"],
        4,
    )


def classify_score(score: float, threshold: float | None = None) -> str:
    w = load_model_state()["weights"]
    cut = threshold if threshold is not None else w.get("threshold", 0.25)
    if score >= cut:
        return "bullish"
    if score <= -cut:
        return "bearish"
    return "neutral"


def adjust_weights(
    weights: dict[str, float],
    component_scores: dict[str, float],
    predicted: str,
    actual: str,
    learning_rate: float | None = None,
) -> dict[str, float]:
    """Nudge factor weights when predictions miss the realized market direction."""
    lr = learning_rate if learning_rate is not None else weights.get("learning_rate", 0.02)
    pred_sign = label_to_sign(predicted)
    actual_sign = label_to_sign(actual)

    updated = {
        "technical": weights["technical"],
        "news": weights["news"],
        "behavior": weights["behavior"],
    }

    if pred_sign == 0 or actual_sign == 0:
        return _normalize(updated)

    correct = pred_sign == actual_sign
    for key, score in component_scores.items():
        if key not in updated:
            continue
        comp_sign = 1 if score > 0.05 else -1 if score < -0.05 else 0
        if comp_sign == 0:
            continue
        if correct and comp_sign == actual_sign:
            updated[key] *= 1 + lr
        elif not correct and comp_sign == pred_sign:
            updated[key] *= 1 - lr

    normalized = _normalize(updated)
    normalized["threshold"] = weights.get("threshold", 0.25)
    normalized["learning_rate"] = lr
    return normalized
