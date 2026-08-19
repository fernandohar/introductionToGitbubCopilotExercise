"""Mock market backtesting: suggest portfolios on a past date and test with real history."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import numpy as np
import pandas as pd

from app.analysis import generate_signals, rsi, sma
from app.history_store import get_available_date_range, get_ohlcv, get_symbol_name, get_universe
from app.symbols import normalize_symbol

HOLD_DAYS = {
    "1mo": 22,
    "3mo": 66,
    "6mo": 132,
    "1y": 252,
}


def _parse_date(value: str) -> pd.Timestamp:
    return pd.Timestamp(datetime.strptime(value, "%Y-%m-%d").date())


def _nearest_on_or_after(index: pd.DatetimeIndex, target: pd.Timestamp) -> pd.Timestamp | None:
    future = index[index >= target]
    if len(future) == 0:
        return None
    return future[0]


def _offset_trading_day(index: pd.DatetimeIndex, start: pd.Timestamp, offset: int) -> pd.Timestamp | None:
    pos = index.get_indexer([start], method="backfill")
    if pos[0] < 0:
        return None
    end_pos = pos[0] + offset
    if end_pos >= len(index):
        return index[-1]
    return index[end_pos]


def score_stock_at_date(close: pd.Series) -> dict[str, Any]:
    """Score a stock using only data available up to the selected date."""
    if len(close) < 50:
        return {"score": 0.0, "signal": "insufficient_data", "rsi": None, "eligible": False}

    signals = generate_signals(close)
    score = 0.0

    overall = signals.get("overall", "neutral")
    if overall == "bullish":
        score += 0.7
    elif overall == "bearish":
        score -= 0.7

    rsi_value = signals.get("rsi")
    if rsi_value is not None:
        if rsi_value < 35:
            score += 0.35
        elif rsi_value > 65:
            score -= 0.35

    sma20 = sma(close, 20)
    sma50 = sma(close, 50)
    if not np.isnan(sma20.iloc[-1]) and not np.isnan(sma50.iloc[-1]):
        if close.iloc[-1] > sma20.iloc[-1] > sma50.iloc[-1]:
            score += 0.25
        elif close.iloc[-1] < sma20.iloc[-1] < sma50.iloc[-1]:
            score -= 0.25

    if len(close) >= 21 and close.iloc[-21] != 0:
        momentum = float(close.iloc[-1] / close.iloc[-21] - 1)
        score += float(np.clip(momentum * 3, -0.35, 0.35))

    return {
        "score": round(score, 3),
        "signal": overall,
        "rsi": rsi_value,
        "eligible": True,
    }


def _build_portfolio(scored: list[dict[str, Any]], top_n: int = 4) -> list[dict[str, Any]]:
    eligible = [item for item in scored if item.get("eligible")]
    eligible.sort(key=lambda item: item["score"], reverse=True)
    picks = eligible[:top_n]

    if not picks:
        return []

    positive_scores = [max(item["score"], 0.05) for item in picks]
    total = sum(positive_scores)
    portfolio: list[dict[str, Any]] = []

    for item, weight_base in zip(picks, positive_scores):
        portfolio.append(
            {
                "symbol": item["symbol"],
                "name": item["name"],
                "weight": round(weight_base / total, 4),
                "score_at_entry": item["score"],
                "signal": item["signal"],
                "rsi": item["rsi"],
                "entry_price": item["entry_price"],
            }
        )

    return portfolio


def _simulate_position(
    frame: pd.DataFrame,
    entry_date: pd.Timestamp,
    exit_date: pd.Timestamp,
    allocation: float,
) -> dict[str, Any]:
    entry_idx = _nearest_on_or_after(frame.index, entry_date)
    exit_idx = _nearest_on_or_after(frame.index, exit_date)
    if entry_idx is None or exit_idx is None:
        raise ValueError("Missing price data for simulation window")

    entry_row = frame.loc[entry_idx]
    exit_row = frame.loc[exit_idx]
    entry_price = float(entry_row["Close"])
    exit_price = float(exit_row["Close"])

    if entry_price <= 0:
        raise ValueError("Invalid entry price")

    shares = allocation / entry_price
    final_value = shares * exit_price
    profit = final_value - allocation
    return_pct = (exit_price / entry_price - 1) * 100

    return {
        "entry_date": entry_idx.strftime("%Y-%m-%d"),
        "exit_date": exit_idx.strftime("%Y-%m-%d"),
        "entry_price": round(entry_price, 4),
        "exit_price": round(exit_price, 4),
        "shares": round(shares, 4),
        "allocation": round(allocation, 2),
        "final_value": round(final_value, 2),
        "profit": round(profit, 2),
        "return_pct": round(return_pct, 2),
    }


def _equity_curve(
    frames: dict[str, pd.DataFrame],
    weights: dict[str, float],
    entry_date: pd.Timestamp,
    exit_date: pd.Timestamp,
    initial_capital: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    dates = sorted(
        {
            d
            for symbol, frame in frames.items()
            for d in frame.index
            if entry_date <= d <= exit_date
        }
    )

    portfolio_curve: list[dict[str, Any]] = []
    benchmark_curve: list[dict[str, Any]] = []
    benchmark_symbols = list(weights.keys())
    benchmark_capital = initial_capital
    benchmark_alloc = benchmark_capital / len(benchmark_symbols) if benchmark_symbols else 0
    benchmark_shares = {}

    entry_prices: dict[str, float] = {}
    shares: dict[str, float] = {}

    for symbol, frame in frames.items():
        entry_idx = _nearest_on_or_after(frame.index, entry_date)
        if entry_idx is None:
            continue
        entry_prices[symbol] = float(frame.loc[entry_idx, "Close"])
        shares[symbol] = (initial_capital * weights[symbol]) / entry_prices[symbol]
        if symbol in benchmark_symbols and entry_prices[symbol] > 0:
            benchmark_shares[symbol] = benchmark_alloc / entry_prices[symbol]

    for day in dates:
        portfolio_value = 0.0
        benchmark_value = 0.0

        for symbol, frame in frames.items():
            available = frame.index[frame.index <= day]
            if len(available) == 0 or symbol not in shares:
                continue
            price = float(frame.loc[available[-1], "Close"])
            portfolio_value += shares[symbol] * price

        for symbol, qty in benchmark_shares.items():
            frame = frames[symbol]
            available = frame.index[frame.index <= day]
            if len(available) == 0:
                continue
            price = float(frame.loc[available[-1], "Close"])
            benchmark_value += qty * price

        day_str = day.strftime("%Y-%m-%d")
        portfolio_curve.append({"date": day_str, "value": round(portfolio_value, 2)})
        benchmark_curve.append({"date": day_str, "value": round(benchmark_value, 2)})

    return portfolio_curve, benchmark_curve


def run_mock_backtest(
    as_of_date: str,
    market: str = "hk",
    hold_period: str = "3mo",
    capital: float = 100_000.0,
    top_n: int = 4,
) -> dict[str, Any]:
    """Suggest a portfolio on a historical date and test forward returns."""
    target_date = _parse_date(as_of_date)
    hold_days = HOLD_DAYS.get(hold_period, HOLD_DAYS["3mo"])
    universe = get_universe(market)
    date_range = get_available_date_range(market)

    if date_range.get("earliest_entry") and target_date < _parse_date(date_range["earliest_entry"]):
        raise ValueError(f"Pick a date on or after {date_range['earliest_entry']}")
    if date_range.get("latest_entry") and target_date > _parse_date(date_range["latest_entry"]):
        raise ValueError(f"Pick a date on or before {date_range['latest_entry']}")

    scored: list[dict[str, Any]] = []
    frames: dict[str, pd.DataFrame] = {}

    for symbol in universe:
        frame = get_ohlcv(symbol)
        if frame is None or frame.empty:
            continue

        history_to_date = frame[frame.index <= target_date]
        if len(history_to_date) < 50:
            continue

        entry_idx = _nearest_on_or_after(frame.index, target_date)
        if entry_idx is None:
            continue

        score_payload = score_stock_at_date(history_to_date["Close"])
        scored.append(
            {
                "symbol": symbol,
                "name": get_symbol_name(symbol),
                "entry_price": round(float(frame.loc[entry_idx, "Close"]), 4),
                **score_payload,
            }
        )
        frames[symbol] = frame

    portfolio = _build_portfolio(scored, top_n=top_n)
    if not portfolio:
        raise ValueError("Not enough historical data to build a portfolio for that date")

    reference_frame = next(iter(frames.values()))
    entry_date = _nearest_on_or_after(reference_frame.index, target_date)
    if entry_date is None:
        raise ValueError("Unable to find entry trading day")

    exit_date = _offset_trading_day(reference_frame.index, entry_date, hold_days)
    if exit_date is None:
        raise ValueError("Unable to find exit trading day")

    weights = {item["symbol"]: item["weight"] for item in portfolio}
    simulated_positions: list[dict[str, Any]] = []
    total_profit = 0.0
    final_value = 0.0
    winners = 0
    losers = 0

    for item in portfolio:
        frame = frames[item["symbol"]]
        allocation = capital * item["weight"]
        result = _simulate_position(frame, entry_date, exit_date, allocation)
        total_profit += result["profit"]
        final_value += result["final_value"]
        if result["profit"] >= 0:
            winners += 1
        else:
            losers += 1
        simulated_positions.append({**item, **result})

    total_return_pct = (final_value / capital - 1) * 100 if capital else 0.0

    benchmark_positions = []
    benchmark_capital_each = capital / len(universe)
    benchmark_final = 0.0
    for symbol in universe:
        frame = frames.get(symbol)
        if frame is None:
            continue
        try:
            result = _simulate_position(frame, entry_date, exit_date, benchmark_capital_each)
            benchmark_final += result["final_value"]
            benchmark_positions.append({"symbol": symbol, **result})
        except ValueError:
            continue

    benchmark_return_pct = (benchmark_final / capital - 1) * 100 if capital else 0.0
    portfolio_curve, benchmark_curve = _equity_curve(
        {symbol: frames[symbol] for symbol in weights},
        weights,
        entry_date,
        exit_date,
        capital,
    )

    currency = "HKD" if market.lower() == "hk" else "USD"
    if market.lower() == "all":
        currency = "Mixed"

    return {
        "as_of_date": as_of_date,
        "entry_date": entry_date.strftime("%Y-%m-%d"),
        "exit_date": exit_date.strftime("%Y-%m-%d"),
        "hold_period": hold_period,
        "hold_days": hold_days,
        "market": market.upper(),
        "currency": currency,
        "initial_capital": capital,
        "portfolio": simulated_positions,
        "summary": {
            "final_value": round(final_value, 2),
            "total_profit": round(total_profit, 2),
            "total_return_pct": round(total_return_pct, 2),
            "benchmark_return_pct": round(benchmark_return_pct, 2),
            "alpha_pct": round(total_return_pct - benchmark_return_pct, 2),
            "beat_benchmark": total_return_pct > benchmark_return_pct,
            "winning_positions": winners,
            "losing_positions": losers,
            "made_money": total_profit > 0,
        },
        "benchmark": {
            "label": "Equal-weight universe buy & hold",
            "final_value": round(benchmark_final, 2),
            "return_pct": round(benchmark_return_pct, 2),
        },
        "equity_curve": {
            "portfolio": portfolio_curve,
            "benchmark": benchmark_curve,
        },
        "methodology": {
            "selection": f"Top {top_n} stocks by point-in-time technical score (RSI, MA trend, momentum)",
            "execution": "Buy at close on entry date; sell at close after hold period",
            "benchmark": "Equal-weight buy-and-hold of full market universe",
        },
        "scored_universe": sorted(scored, key=lambda item: item["score"], reverse=True),
    }
