"""Load full OHLCV history for backtesting."""

from __future__ import annotations

from typing import Any

import pandas as pd
import yfinance as yf

from app.providers import demo
from app.symbols import HK_POPULAR, US_POPULAR, normalize_symbol


def get_symbol_name(symbol: str) -> str:
    normalized = normalize_symbol(symbol)
    for item in HK_POPULAR:
        if item["symbol"] == normalized:
            return item["name"]
    payload = demo.load_symbol_payload(normalized)
    if payload:
        return payload.get("name", normalized)
    return normalized


def get_ohlcv(symbol: str) -> pd.DataFrame | None:
    """Return full daily OHLCV history for a symbol."""
    normalized = normalize_symbol(symbol)
    frame = demo.get_ohlcv_frame(normalized)
    if frame is not None and not frame.empty:
        return frame.sort_index()

    try:
        raw = yf.download(
            normalized,
            period="5y",
            auto_adjust=True,
            progress=False,
            threads=False,
        )
    except Exception:
        return None

    if raw.empty:
        return None

    df = raw.copy()
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)

    expected = ["Open", "High", "Low", "Close", "Volume"]
    if not all(col in df.columns for col in expected):
        return None

    return df[expected].sort_index()


def get_universe(market: str) -> list[str]:
    market_key = market.lower()
    if market_key == "hk":
        return [item["symbol"] for item in HK_POPULAR]
    if market_key == "us":
        return US_POPULAR.copy()
    return [item["symbol"] for item in HK_POPULAR] + US_POPULAR


def get_available_date_range(market: str, symbols: list[str] | None = None) -> dict[str, Any]:
    symbol_list = symbols or get_universe(market)
    min_date = None
    max_date = None

    for symbol in symbol_list:
        frame = get_ohlcv(symbol)
        if frame is None or frame.empty:
            continue
        start = frame.index.min()
        end = frame.index.max()
        min_date = start if min_date is None else max(min_date, start)
        max_date = end if max_date is None else min(max_date, end)

    if min_date is None or max_date is None:
        return {"market": market, "start": None, "end": None}

    # Require warmup history and room for a 3-month hold
    earliest_entry = min_date + pd.Timedelta(days=90)
    latest_entry = max_date - pd.Timedelta(days=66)

    return {
        "market": market,
        "data_start": min_date.strftime("%Y-%m-%d"),
        "data_end": max_date.strftime("%Y-%m-%d"),
        "earliest_entry": earliest_entry.strftime("%Y-%m-%d"),
        "latest_entry": latest_entry.strftime("%Y-%m-%d") if latest_entry > earliest_entry else earliest_entry.strftime("%Y-%m-%d"),
    }
