"""Technical analysis calculations for stock price series."""

from __future__ import annotations

import numpy as np
import pandas as pd


def sma(series: pd.Series, window: int) -> pd.Series:
    return series.rolling(window=window, min_periods=window).mean()


def ema(series: pd.Series, window: int) -> pd.Series:
    return series.ewm(span=window, adjust=False, min_periods=window).mean()


def rsi(series: pd.Series, window: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = (-delta).clip(lower=0)
    avg_gain = gain.ewm(alpha=1 / window, min_periods=window, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / window, min_periods=window, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def macd(
    series: pd.Series, fast: int = 12, slow: int = 26, signal: int = 9
) -> tuple[pd.Series, pd.Series, pd.Series]:
    fast_ema = ema(series, fast)
    slow_ema = ema(series, slow)
    macd_line = fast_ema - slow_ema
    signal_line = macd_line.ewm(span=signal, adjust=False, min_periods=signal).mean()
    histogram = macd_line - signal_line
    return macd_line, signal_line, histogram


def bollinger_bands(
    series: pd.Series, window: int = 20, num_std: float = 2.0
) -> tuple[pd.Series, pd.Series, pd.Series]:
    middle = sma(series, window)
    std = series.rolling(window=window, min_periods=window).std()
    upper = middle + num_std * std
    lower = middle - num_std * std
    return upper, middle, lower


def generate_signals(close: pd.Series) -> dict[str, str | float | None]:
    """Produce simple rule-based signals from RSI and moving-average crossovers."""
    if len(close) < 50:
        return {"overall": "neutral", "rsi": None, "ma_cross": "insufficient_data"}

    current_rsi = float(rsi(close).iloc[-1])
    sma20 = sma(close, 20)
    sma50 = sma(close, 50)

    ma_cross = "neutral"
    if not np.isnan(sma20.iloc[-1]) and not np.isnan(sma50.iloc[-1]):
        prev_diff = sma20.iloc[-2] - sma50.iloc[-2]
        curr_diff = sma20.iloc[-1] - sma50.iloc[-1]
        if prev_diff <= 0 < curr_diff:
            ma_cross = "bullish_cross"
        elif prev_diff >= 0 > curr_diff:
            ma_cross = "bearish_cross"
        elif curr_diff > 0:
            ma_cross = "bullish"
        else:
            ma_cross = "bearish"

    score = 0
    if current_rsi < 30:
        score += 1
    elif current_rsi > 70:
        score -= 1

    if ma_cross in ("bullish_cross", "bullish"):
        score += 1
    elif ma_cross in ("bearish_cross", "bearish"):
        score -= 1

    if score >= 1:
        overall = "bullish"
    elif score <= -1:
        overall = "bearish"
    else:
        overall = "neutral"

    return {"overall": overall, "rsi": round(current_rsi, 2), "ma_cross": ma_cross}


def enrich_history(df: pd.DataFrame) -> pd.DataFrame:
    """Add indicator columns to an OHLCV dataframe."""
    out = df.copy()
    close = out["Close"]

    out["SMA20"] = sma(close, 20)
    out["SMA50"] = sma(close, 50)
    out["SMA200"] = sma(close, 200)
    out["EMA12"] = ema(close, 12)
    out["EMA26"] = ema(close, 26)
    out["RSI"] = rsi(close)

    macd_line, signal_line, histogram = macd(close)
    out["MACD"] = macd_line
    out["MACD_Signal"] = signal_line
    out["MACD_Hist"] = histogram

    upper, middle, lower = bollinger_bands(close)
    out["BB_Upper"] = upper
    out["BB_Middle"] = middle
    out["BB_Lower"] = lower

    return out
