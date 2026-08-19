"""Combined trend analysis from technicals, news sentiment, and trading behavior."""

from __future__ import annotations

from typing import Any

from app.adaptive_model import load_model_state
from app.data import get_history
from app.news import get_news
from app.symbols import is_hk_symbol, normalize_symbol
from app.trend_engine import (
    overall_from_components,
    score_behavior,
    score_news_live,
    score_technical,
)


def get_trend_analysis(symbol: str, period: str = "6mo") -> dict[str, Any]:
    normalized = normalize_symbol(symbol)
    history = get_history(normalized, period=period)
    news_payload = get_news(normalized)
    weights = load_model_state()["weights"]

    technical = score_technical(history)
    news = score_news_live(news_payload)
    behavior = score_behavior(history)
    overall = overall_from_components(technical, news, behavior, weights)

    if overall["label"] == "bullish":
        overall["suggested_action"] = "Bias toward buying on dips; confirm with volume and news flow."
    elif overall["label"] == "bearish":
        overall["suggested_action"] = "Bias toward reducing exposure; watch for negative news confirmation."
    else:
        overall["suggested_action"] = "Wait for clearer alignment between news, price trend, and volume."

    return {
        "symbol": normalized,
        "market": "HK" if is_hk_symbol(normalized) else "US",
        "currency": "HKD" if is_hk_symbol(normalized) else "USD",
        "period": period,
        "overall": overall,
        "technical": technical,
        "news": news,
        "behavior": behavior,
        "model_weights": {
            "technical": weights["technical"],
            "news": weights["news"],
            "behavior": weights["behavior"],
        },
        "recent_news": news_payload.get("items", [])[:6],
        "source": history.get("source", "unknown"),
    }
