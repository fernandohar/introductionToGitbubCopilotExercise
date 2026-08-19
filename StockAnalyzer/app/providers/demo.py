"""Demo/sample market data loaded from bundled JSON files."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

import pandas as pd

from app.analysis import enrich_history, generate_signals

SAMPLES_DIR = Path(__file__).resolve().parent.parent.parent / "data" / "samples"

PERIOD_DAYS = {
    "1mo": 22,
    "3mo": 66,
    "6mo": 132,
    "1y": 252,
    "2y": 504,
    "5y": 1260,
    "max": 10_000,
}


@lru_cache(maxsize=32)
def _load_symbol_file(symbol: str) -> dict[str, Any] | None:
    path = SAMPLES_DIR / f"{symbol.upper()}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text())


@lru_cache(maxsize=1)
def _load_catalog() -> dict[str, Any]:
    path = SAMPLES_DIR / "catalog.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def available_symbols() -> list[str]:
    return sorted(_load_catalog().keys())


def search_symbols(query: str, limit: int = 10) -> list[dict[str, str]]:
    query = query.strip().upper()
    catalog = _load_catalog()
    results: list[dict[str, str]] = []

    for symbol, meta in catalog.items():
        name = meta.get("name", symbol)
        if query in symbol or query in name.upper():
            results.append(
                {
                    "symbol": symbol,
                    "name": name,
                    "exchange": "DEMO",
                    "type": "EQUITY",
                }
            )
        if len(results) >= limit:
            break

    return results


def _rows_to_frame(rows: list[dict[str, Any]]) -> pd.DataFrame:
    df = pd.DataFrame(rows)
    df["Date"] = pd.to_datetime(df["date"])
    df = df.set_index("Date")
    df = df.rename(
        columns={
            "open": "Open",
            "high": "High",
            "low": "Low",
            "close": "Close",
            "volume": "Volume",
        }
    )
    return df[["Open", "High", "Low", "Close", "Volume"]]


def _slice_period(df: pd.DataFrame, period: str) -> pd.DataFrame:
    days = PERIOD_DAYS.get(period, 252)
    if len(df) <= days:
        return df
    return df.iloc[-days:]


def get_quote(symbol: str) -> dict[str, Any]:
    payload = _load_symbol_file(symbol)
    if not payload:
        raise ValueError(f"Sample data unavailable for {symbol}")

    rows = payload["history"]
    if len(rows) < 2:
        raise ValueError(f"Insufficient sample data for {symbol}")

    price = rows[-1]["close"]
    prev_close = rows[-2]["close"]
    change = round(price - prev_close, 4)
    change_pct = round((change / prev_close) * 100, 4) if prev_close else None

    return {
        "symbol": symbol.upper(),
        "name": payload.get("name", symbol.upper()),
        "price": price,
        "change": change,
        "change_percent": change_pct,
        "currency": payload.get("currency", "USD"),
        "market_state": "REGULAR",
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "source": "demo",
    }


def get_fundamentals(symbol: str) -> dict[str, Any]:
    payload = _load_symbol_file(symbol)
    if not payload:
        return {"symbol": symbol.upper()}

    rows = payload["history"]
    closes = [row["close"] for row in rows]
    volumes = [row["volume"] for row in rows[-60:]]

    return {
        "symbol": symbol.upper(),
        "sector": payload.get("sector"),
        "industry": payload.get("industry"),
        "market_cap": round(closes[-1] * 1_500_000_000, 2),
        "enterprise_value": round(closes[-1] * 1_550_000_000, 2),
        "pe_ratio": round(20 + (hash(symbol) % 15), 2),
        "forward_pe": round(18 + (hash(symbol) % 10), 2),
        "peg_ratio": round(1.2 + (hash(symbol) % 8) / 10, 2),
        "price_to_book": round(5 + (hash(symbol) % 20), 2),
        "eps": round(closes[-1] / 25, 2),
        "dividend_yield": 0.005 if symbol != "TSLA" else None,
        "beta": round(0.8 + (hash(symbol) % 12) / 10, 2),
        "fifty_two_week_high": max(closes[-252:]) if len(closes) >= 252 else max(closes),
        "fifty_two_week_low": min(closes[-252:]) if len(closes) >= 252 else min(closes),
        "avg_volume": int(sum(volumes) / len(volumes)) if volumes else None,
        "description": f"Demo profile for {payload.get('name', symbol)}. Enable live data with FINNHUB_API_KEY or retry Yahoo Finance later.",
        "source": "demo",
    }


def get_history(symbol: str, period: str = "1y") -> dict[str, Any]:
    payload = _load_symbol_file(symbol)
    if not payload:
        return {"symbol": symbol.upper(), "period": period, "history": [], "signals": {}}

    df = _slice_period(_rows_to_frame(payload["history"]), period)
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
        "source": "demo",
    }


def compare_symbols(symbols: list[str], period: str = "1y") -> dict[str, Any]:
    series: list[dict[str, Any]] = []
    for symbol in symbols:
        payload = _load_symbol_file(symbol)
        if not payload:
            continue

        df = _slice_period(_rows_to_frame(payload["history"]), period)
        if df.empty:
            continue

        base = float(df["Close"].iloc[0])
        points = []
        for idx, value in df["Close"].items():
            points.append(
                {
                    "date": idx.strftime("%Y-%m-%d"),
                    "value": round((float(value) / base - 1) * 100, 4),
                }
            )
        series.append({"symbol": symbol.upper(), "points": points})

    return {"period": period, "series": series, "source": "demo"}
