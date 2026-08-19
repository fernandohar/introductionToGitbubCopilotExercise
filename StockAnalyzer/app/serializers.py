"""Shared serialization helpers."""

from __future__ import annotations

from typing import Any

import pandas as pd


def safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        result = float(value)
        if pd.isna(result):
            return None
        return result
    except (TypeError, ValueError):
        return None


def format_history(df: pd.DataFrame) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for idx, row in df.iterrows():
        date_str = idx.strftime("%Y-%m-%d") if hasattr(idx, "strftime") else str(idx)[:10]
        record: dict[str, Any] = {
            "date": date_str,
            "open": safe_float(row.get("Open")),
            "high": safe_float(row.get("High")),
            "low": safe_float(row.get("Low")),
            "close": safe_float(row.get("Close")),
            "volume": safe_float(row.get("Volume")),
        }
        for key in (
            "SMA20",
            "SMA50",
            "SMA200",
            "EMA12",
            "EMA26",
            "RSI",
            "MACD",
            "MACD_Signal",
            "MACD_Hist",
            "BB_Upper",
            "BB_Middle",
            "BB_Lower",
        ):
            if key in row:
                record[key.lower()] = safe_float(row[key])
        records.append(record)
    return records
