"""Optional Finnhub live market data provider."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

import httpx
import pandas as pd

from app.analysis import enrich_history, generate_signals

FINNHUB_BASE = "https://finnhub.io/api/v1"
PERIOD_SECONDS = {
    "1mo": 30 * 24 * 3600,
    "3mo": 90 * 24 * 3600,
    "6mo": 180 * 24 * 3600,
    "1y": 365 * 24 * 3600,
    "2y": 730 * 24 * 3600,
    "5y": 5 * 365 * 24 * 3600,
    "max": 10 * 365 * 24 * 3600,
}


def is_configured() -> bool:
    return bool(os.getenv("FINNHUB_API_KEY", "").strip())


def _token() -> str:
    token = os.getenv("FINNHUB_API_KEY", "").strip()
    if not token:
        raise RuntimeError("FINNHUB_API_KEY is not configured")
    return token


def _get(path: str, params: dict[str, Any] | None = None) -> Any:
    query = {"token": _token(), **(params or {})}
    response = httpx.get(f"{FINNHUB_BASE}{path}", params=query, timeout=20.0)
    response.raise_for_status()
    return response.json()


def search_symbols(query: str, limit: int = 10) -> list[dict[str, str]]:
    data = _get("/search", {"q": query})
    results: list[dict[str, str]] = []
    for item in data.get("result", [])[:limit]:
        symbol = item.get("symbol")
        if not symbol:
            continue
        results.append(
            {
                "symbol": symbol,
                "name": item.get("description") or symbol,
                "exchange": item.get("exchange") or "",
                "type": item.get("type") or "",
            }
        )
    return results


def get_quote(symbol: str) -> dict[str, Any]:
    quote = _get("/quote", {"symbol": symbol.upper()})
    profile = _get("/stock/profile2", {"symbol": symbol.upper()})

    price = quote.get("c")
    prev_close = quote.get("pc")
    change = round(price - prev_close, 4) if price is not None and prev_close else None
    change_pct = round((change / prev_close) * 100, 4) if change is not None and prev_close else None

    return {
        "symbol": symbol.upper(),
        "name": profile.get("name") or symbol.upper(),
        "price": price,
        "change": change,
        "change_percent": change_pct,
        "currency": profile.get("currency") or "USD",
        "market_state": "REGULAR",
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "source": "finnhub",
    }


def get_fundamentals(symbol: str) -> dict[str, Any]:
    profile = _get("/stock/profile2", {"symbol": symbol.upper()})
    metric = _get("/stock/metric", {"symbol": symbol.upper(), "metric": "all"})

    m = metric.get("metric", {})
    market_cap = m.get("marketCapitalization")
    if market_cap is not None:
        market_cap = market_cap * 1_000_000

    return {
        "symbol": symbol.upper(),
        "sector": profile.get("finnhubIndustry"),
        "industry": profile.get("finnhubIndustry"),
        "market_cap": market_cap,
        "enterprise_value": m.get("enterpriseValue"),
        "pe_ratio": m.get("peBasicExclExtraTTM"),
        "forward_pe": m.get("peNormalizedAnnual"),
        "peg_ratio": m.get("pegRatio"),
        "price_to_book": m.get("pbAnnual"),
        "eps": m.get("epsBasicExclExtraItemsTTM"),
        "dividend_yield": m.get("dividendYieldIndicatedAnnual"),
        "beta": m.get("beta"),
        "fifty_two_week_high": m.get("52WeekHigh"),
        "fifty_two_week_low": m.get("52WeekLow"),
        "avg_volume": m.get("10DayAverageTradingVolume"),
        "description": profile.get("name") or "",
        "source": "finnhub",
    }


def get_history(symbol: str, period: str = "1y") -> dict[str, Any]:
    now = int(datetime.now(timezone.utc).timestamp())
    start = now - PERIOD_SECONDS.get(period, PERIOD_SECONDS["1y"])
    candles = _get(
        "/stock/candle",
        {"symbol": symbol.upper(), "resolution": "D", "from": start, "to": now},
    )

    if candles.get("s") != "ok":
        return {"symbol": symbol.upper(), "period": period, "history": [], "signals": {}}

    df = pd.DataFrame(
        {
            "Open": candles["o"],
            "High": candles["h"],
            "Low": candles["l"],
            "Close": candles["c"],
            "Volume": candles["v"],
        },
        index=pd.to_datetime(candles["t"], unit="s"),
    )

    enriched = enrich_history(df)
    signals = generate_signals(enriched["Close"])
    latest = enriched.iloc[-1]

    from app.serializers import format_history

    return {
        "symbol": symbol.upper(),
        "period": period,
        "history": format_history(enriched),
        "summary": {
            "latest_close": float(latest["Close"]),
            "rsi": float(latest["RSI"]) if pd.notna(latest["RSI"]) else None,
            "sma20": float(latest["SMA20"]) if pd.notna(latest["SMA20"]) else None,
            "sma50": float(latest["SMA50"]) if pd.notna(latest["SMA50"]) else None,
            "sma200": float(latest["SMA200"]) if pd.notna(latest["SMA200"]) else None,
        },
        "signals": signals,
        "source": "finnhub",
    }


def compare_symbols(symbols: list[str], period: str = "1y") -> dict[str, Any]:
    series: list[dict[str, Any]] = []
    for symbol in symbols[:5]:
        history = get_history(symbol, period)
        points = [
            {"date": row["date"], "value": 0.0}
            for row in history.get("history", [])[:1]
        ]
        closes = history.get("history", [])
        if not closes:
            continue
        base = closes[0]["close"]
        points = [
            {
                "date": row["date"],
                "value": round((row["close"] / base - 1) * 100, 4) if base else 0,
            }
            for row in closes
        ]
        series.append({"symbol": symbol.upper(), "points": points})

    return {"period": period, "series": series, "source": "finnhub"}
