"""Lightweight keyword-based sentiment scoring for news headlines."""

from __future__ import annotations

import re

POSITIVE = {
    "surge",
    "soar",
    "rally",
    "gain",
    "gains",
    "rise",
    "rises",
    "rising",
    "bullish",
    "upgrade",
    "upgraded",
    "beat",
    "beats",
    "record",
    "growth",
    "strong",
    "outperform",
    "optimistic",
    "recovery",
    "rebound",
    "profit",
    "profits",
    "expansion",
    "boost",
    "buy",
    "accumulate",
    "positive",
    "approval",
    "breakout",
    "momentum",
}

NEGATIVE = {
    "fall",
    "falls",
    "drop",
    "drops",
    "plunge",
    "plunges",
    "decline",
    "declines",
    "slump",
    "bearish",
    "downgrade",
    "downgraded",
    "miss",
    "misses",
    "loss",
    "losses",
    "weak",
    "warning",
    "concern",
    "concerns",
    "risk",
    "risks",
    "sanction",
    "sanctions",
    "probe",
    "investigation",
    "lawsuit",
    "cut",
    "cuts",
    "sell",
    "selling",
    "negative",
    "crash",
    "crisis",
    "slowdown",
    "default",
    "tariff",
    "tariffs",
}

WORD = re.compile(r"[a-zA-Z']+")


def score_text(text: str) -> dict[str, float | str]:
    words = [w.lower() for w in WORD.findall(text or "")]
    if not words:
        return {"score": 0.0, "label": "neutral", "positive_hits": 0, "negative_hits": 0}

    pos = sum(1 for w in words if w in POSITIVE)
    neg = sum(1 for w in words if w in NEGATIVE)
    total = pos + neg
    score = 0.0 if total == 0 else round((pos - neg) / total, 3)

    if score >= 0.25:
        label = "positive"
    elif score <= -0.25:
        label = "negative"
    else:
        label = "neutral"

    return {
        "score": score,
        "label": label,
        "positive_hits": pos,
        "negative_hits": neg,
    }


def aggregate_sentiment(items: list[dict]) -> dict[str, float | str | int]:
    if not items:
        return {"score": 0.0, "label": "neutral", "count": 0}

    scores = [item.get("sentiment_score", 0.0) for item in items]
    avg = round(sum(scores) / len(scores), 3)

    if avg >= 0.15:
        label = "positive"
    elif avg <= -0.15:
        label = "negative"
    else:
        label = "neutral"

    return {"score": avg, "label": label, "count": len(items)}
