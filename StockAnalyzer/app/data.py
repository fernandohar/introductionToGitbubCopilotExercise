"""Stock data retrieval with Yahoo Finance, Finnhub, and demo fallbacks."""

from __future__ import annotations

import os
import time
from datetime import datetime, timezone
from typing import Any

import pandas as pd
import yfinance as yf

from app.analysis import enrich_history, generate_signals
from app.providers import demo, finnhub
from app.serializers import format_history, safe_float
from app.symbols import normalize_symbol, search_hk_catalog

PERIOD_MAP = {
    "1mo": "1mo",
    "3mo": "3mo",
    "6mo": "6mo",
    "1y": "1y",
    "2y": "2y",
    "5y": "5y",
    "max": "max",
}

_CACHE: dict[str, tuple[float, Any]] = {}
_CACHE_TTL_SECONDS = 300


def active_source() -> str:
    if os.getenv("USE_DEMO_DATA", "").lower() in {"1", "true", "yes"}:
        return "demo"
    if finnhub.is_configured():
        return "finnhub"
    return "yahoo"


def _cache_get(key: str) -> Any | None:
    entry = _CACHE.get(key)
    if not entry:
        return None
    expires_at, value = entry
    if time.time() > expires_at:
        _CACHE.pop(key, None)
        return None
    return value


def _cache_set(key: str, value: Any) -> None:
    _CACHE[key] = (time.time() + _CACHE_TTL_SECONDS, value)


def _normalize_history_df(raw: pd.DataFrame) -> pd.DataFrame:
    if raw.empty:
        return raw

    df = raw.copy()
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)

    expected = ["Open", "High", "Low", "Close", "Volume"]
    missing = [col for col in expected if col not in df.columns]
    if missing:
        return pd.DataFrame()

    return df[expected]


def _download_history(symbol: str, period: str) -> pd.DataFrame:
    cache_key = f"history:{symbol}:{period}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached.copy()

    raw = yf.download(
        symbol,
        period=period,
        auto_adjust=True,
        progress=False,
        threads=False,
    )
    df = _normalize_history_df(raw)
    if not df.empty:
        _cache_set(cache_key, df.copy())
    return df


def _try_ticker_info(symbol: str) -> dict[str, Any]:
    cache_key = f"info:{symbol}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        info = yf.Ticker(symbol).info or {}
        _cache_set(cache_key, info)
        return info
    except Exception:
        return {}


def _yahoo_search(query: str, limit: int) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    try:
        results = yf.Search(query, max_results=limit)
        quotes = results.quotes if hasattr(results, "quotes") else []
        for quote in quotes[:limit]:
            symbol = quote.get("symbol") or quote.get("ticker")
            if not symbol:
                continue
            items.append(
                {
                    "symbol": symbol,
                    "name": quote.get("longname") or quote.get("shortname") or symbol,
                    "exchange": quote.get("exchange") or "",
                    "type": quote.get("quoteType") or "",
                }
            )
    except Exception:
        pass

    if not items and query.replace(".", "").replace("-", "").isalnum() and len(query) <= 8:
        info = _try_ticker_info(query)
        items.append(
            {
                "symbol": query,
                "name": info.get("longName") or info.get("shortName") or query,
                "exchange": info.get("exchange") or "",
                "type": info.get("quoteType") or "EQUITY",
            }
        )
    return items


def _yahoo_quote(symbol: str) -> dict[str, Any]:
    symbol = symbol.upper()
    info = _try_ticker_info(symbol)
    recent = _download_history(symbol, "5d")
    if recent.empty:
        raise ValueError(f"No market data available for {symbol}")

    price = safe_float(recent["Close"].iloc[-1])
    prev_close = safe_float(recent["Close"].iloc[-2]) if len(recent) > 1 else safe_float(
        info.get("previousClose")
    )

    change = None
    change_pct = None
    if price is not None and prev_close is not None and prev_close != 0:
        change = round(price - prev_close, 4)
        change_pct = round((change / prev_close) * 100, 4)

    return {
        "symbol": symbol,
        "name": info.get("longName") or info.get("shortName") or symbol,
        "price": price,
        "change": change,
        "change_percent": change_pct,
        "currency": info.get("currency") or "USD",
        "market_state": info.get("marketState") or "UNKNOWN",
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "source": "yahoo",
    }


def _yahoo_fundamentals(symbol: str) -> dict[str, Any]:
    symbol = symbol.upper()
    info = _try_ticker_info(symbol)
    return {
        "symbol": symbol,
        "sector": info.get("sector"),
        "industry": info.get("industry"),
        "market_cap": safe_float(info.get("marketCap")),
        "enterprise_value": safe_float(info.get("enterpriseValue")),
        "pe_ratio": safe_float(info.get("trailingPE")),
        "forward_pe": safe_float(info.get("forwardPE")),
        "peg_ratio": safe_float(info.get("pegRatio")),
        "price_to_book": safe_float(info.get("priceToBook")),
        "eps": safe_float(info.get("trailingEps")),
        "dividend_yield": safe_float(info.get("dividendYield")),
        "beta": safe_float(info.get("beta")),
        "fifty_two_week_high": safe_float(info.get("fiftyTwoWeekHigh")),
        "fifty_two_week_low": safe_float(info.get("fiftyTwoWeekLow")),
        "avg_volume": safe_float(info.get("averageVolume")),
        "description": (info.get("longBusinessSummary") or "")[:500],
        "source": "yahoo",
    }


def _yahoo_history(symbol: str, period: str) -> dict[str, Any]:
    symbol = symbol.upper()
    period_key = PERIOD_MAP.get(period, "1y")
    df = _download_history(symbol, period_key)
    if df.empty:
        return {"symbol": symbol, "period": period_key, "history": [], "signals": {}}

    enriched = enrich_history(df)
    signals = generate_signals(enriched["Close"])
    latest = enriched.iloc[-1]

    return {
        "symbol": symbol,
        "period": period_key,
        "history": format_history(enriched),
        "summary": {
            "latest_close": safe_float(latest["Close"]),
            "rsi": safe_float(latest["RSI"]),
            "sma20": safe_float(latest["SMA20"]),
            "sma50": safe_float(latest["SMA50"]),
            "sma200": safe_float(latest["SMA200"]),
        },
        "signals": signals,
        "source": "yahoo",
    }


def _extract_close_series(raw: pd.DataFrame, symbol: str) -> pd.Series:
    if raw.empty:
        return pd.Series(dtype=float)

    if isinstance(raw.columns, pd.MultiIndex):
        if symbol in raw.columns.get_level_values(0):
            close = raw[symbol]["Close"]
        else:
            close = raw["Close"]
    else:
        close = raw["Close"]

    return close.dropna()


def _yahoo_compare(symbols: list[str], period: str) -> dict[str, Any]:
    period_key = PERIOD_MAP.get(period, "1y")
    normalized = [s for s in symbols if s.strip()][:5]
    raw = yf.download(
        normalized,
        period=period_key,
        auto_adjust=True,
        group_by="ticker",
        progress=False,
        threads=False,
    )

    series: list[dict[str, Any]] = []
    for symbol in normalized:
        close = _extract_close_series(raw, symbol)
        if close.empty:
            continue
        base = float(close.iloc[0])
        points = []
        for idx, value in close.items():
            date_str = idx.strftime("%Y-%m-%d") if hasattr(idx, "strftime") else str(idx)[:10]
            points.append({"date": date_str, "value": round((float(value) / base - 1) * 100, 4)})
        series.append({"symbol": symbol, "points": points})

    return {"period": period_key, "series": series, "source": "yahoo"}


def _with_fallback(primary, fallback, *args, **kwargs):
    try:
        return primary(*args, **kwargs)
    except Exception:
        return fallback(*args, **kwargs)


def search_symbols(query: str, limit: int = 10) -> list[dict[str, str]]:
    hk_results = search_hk_catalog(query, limit=limit)
    source = active_source()
    if source == "demo":
        results = demo.search_symbols(query, limit)
        merged = _merge_search_results(hk_results, results)
        return merged or _yahoo_search(query, limit) or hk_results
    if source == "finnhub":
        live = _with_fallback(finnhub.search_symbols, demo.search_symbols, query, limit)
        return _merge_search_results(hk_results, live)
    results = _yahoo_search(query, limit)
    merged = _merge_search_results(hk_results, results)
    return merged or demo.search_symbols(query, limit) or hk_results


def _merge_search_results(*groups: list[dict[str, str]]) -> list[dict[str, str]]:
    merged: list[dict[str, str]] = []
    seen: set[str] = set()
    for group in groups:
        for item in group:
            symbol = item.get("symbol", "").upper()
            if not symbol or symbol in seen:
                continue
            seen.add(symbol)
            merged.append(item)
    return merged


def get_quote(symbol: str) -> dict[str, Any]:
    symbol = normalize_symbol(symbol)
    source = active_source()
    if source == "demo":
        return demo.get_quote(symbol)
    if source == "finnhub":
        return _with_fallback(finnhub.get_quote, demo.get_quote, symbol)
    return _with_fallback(_yahoo_quote, demo.get_quote, symbol)


def get_fundamentals(symbol: str) -> dict[str, Any]:
    symbol = normalize_symbol(symbol)
    source = active_source()
    if source == "demo":
        return demo.get_fundamentals(symbol)
    if source == "finnhub":
        return _with_fallback(finnhub.get_fundamentals, demo.get_fundamentals, symbol)
    try:
        return _yahoo_fundamentals(symbol)
    except Exception:
        return demo.get_fundamentals(symbol)


def get_history(symbol: str, period: str = "1y") -> dict[str, Any]:
    symbol = normalize_symbol(symbol)
    source = active_source()
    if source == "demo":
        return demo.get_history(symbol, period)
    if source == "finnhub":
        return _with_fallback(finnhub.get_history, demo.get_history, symbol, period)
    result = _yahoo_history(symbol, period)
    if result.get("history"):
        return result
    return demo.get_history(symbol, period)


def compare_symbols(symbols: list[str], period: str = "1y") -> dict[str, Any]:
    symbols = [normalize_symbol(s) for s in symbols if s.strip()]
    source = active_source()
    if source == "demo":
        return demo.compare_symbols(symbols, period)
    if source == "finnhub":
        return _with_fallback(finnhub.compare_symbols, demo.compare_symbols, symbols, period)
    result = _yahoo_compare(symbols, period)
    if result.get("series"):
        return result
    return demo.compare_symbols(symbols, period)
