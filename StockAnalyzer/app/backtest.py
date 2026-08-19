"""Mock market backtesting: suggest portfolios on a past date and test with real history."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import numpy as np
import pandas as pd

from app.analysis import generate_signals, sma
from app.history_store import get_available_date_range, get_ohlcv, get_symbol_name, get_universe
from app.symbols import normalize_symbol

HOLD_DAYS = {
    "1mo": 22,
    "3mo": 66,
    "6mo": 132,
    "1y": 252,
}


def parse_symbol_list(raw: str | None) -> list[str]:
    if not raw:
        return []
    seen: set[str] = set()
    symbols: list[str] = []
    for part in raw.split(","):
        symbol = normalize_symbol(part.strip())
        if symbol and symbol not in seen:
            seen.add(symbol)
            symbols.append(symbol)
    return symbols


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


def _build_scored_universe(
    universe: list[str], target_date: pd.Timestamp
) -> tuple[list[dict[str, Any]], dict[str, pd.DataFrame]]:
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

    return scored, frames


def _build_auto_portfolio(scored: list[dict[str, Any]], top_n: int) -> list[dict[str, Any]]:
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


def _build_manual_portfolio(symbols: list[str], frames: dict[str, pd.DataFrame], target_date: pd.Timestamp) -> list[dict[str, Any]]:
    valid = [symbol for symbol in symbols if symbol in frames]
    if not valid:
        return []

    weight = round(1 / len(valid), 4)
    portfolio: list[dict[str, Any]] = []
    for symbol in valid:
        frame = frames[symbol]
        entry_idx = _nearest_on_or_after(frame.index, target_date)
        if entry_idx is None:
            continue
        history_to_date = frame[frame.index <= target_date]
        score_payload = score_stock_at_date(history_to_date["Close"]) if len(history_to_date) >= 50 else {
            "score": 0.0,
            "signal": "manual",
            "rsi": None,
        }
        portfolio.append(
            {
                "symbol": symbol,
                "name": get_symbol_name(symbol),
                "weight": weight,
                "score_at_entry": score_payload["score"],
                "signal": "manual_pick",
                "rsi": score_payload.get("rsi"),
                "entry_price": round(float(frame.loc[entry_idx, "Close"]), 4),
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

    entry_price = float(frame.loc[entry_idx, "Close"])
    exit_price = float(frame.loc[exit_idx, "Close"])
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
) -> list[dict[str, Any]]:
    dates = sorted(
        {
            d
            for symbol, frame in frames.items()
            for d in frame.index
            if entry_date <= d <= exit_date
        }
    )

    shares: dict[str, float] = {}
    for symbol, weight in weights.items():
        frame = frames.get(symbol)
        if frame is None:
            continue
        entry_idx = _nearest_on_or_after(frame.index, entry_date)
        if entry_idx is None:
            continue
        entry_price = float(frame.loc[entry_idx, "Close"])
        if entry_price > 0:
            shares[symbol] = (initial_capital * weight) / entry_price

    curve: list[dict[str, Any]] = []
    for day in dates:
        value = 0.0
        for symbol, qty in shares.items():
            frame = frames[symbol]
            available = frame.index[frame.index <= day]
            if len(available) == 0:
                continue
            value += qty * float(frame.loc[available[-1], "Close"])
        curve.append({"date": day.strftime("%Y-%m-%d"), "value": round(value, 2)})
    return curve


def _simulate_portfolio(
    portfolio: list[dict[str, Any]],
    frames: dict[str, pd.DataFrame],
    entry_date: pd.Timestamp,
    exit_date: pd.Timestamp,
    capital: float,
) -> dict[str, Any]:
    simulated: list[dict[str, Any]] = []
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
        simulated.append({**item, **result})

    total_return_pct = (final_value / capital - 1) * 100 if capital else 0.0
    weights = {item["symbol"]: item["weight"] for item in portfolio}

    return {
        "portfolio": simulated,
        "summary": {
            "final_value": round(final_value, 2),
            "total_profit": round(total_profit, 2),
            "total_return_pct": round(total_return_pct, 2),
            "winning_positions": winners,
            "losing_positions": losers,
            "made_money": total_profit > 0,
        },
        "equity_curve": _equity_curve(
            {symbol: frames[symbol] for symbol in weights},
            weights,
            entry_date,
            exit_date,
            capital,
        ),
    }


def _simulate_benchmark(
    universe: list[str],
    frames: dict[str, pd.DataFrame],
    entry_date: pd.Timestamp,
    exit_date: pd.Timestamp,
    capital: float,
) -> dict[str, Any]:
    valid = [symbol for symbol in universe if symbol in frames]
    if not valid:
        return {"label": "Equal-weight universe buy & hold", "final_value": capital, "return_pct": 0.0, "equity_curve": []}

    alloc_each = capital / len(valid)
    final_value = 0.0
    for symbol in valid:
        result = _simulate_position(frames[symbol], entry_date, exit_date, alloc_each)
        final_value += result["final_value"]

    weights = {symbol: 1 / len(valid) for symbol in valid}
    return {
        "label": "Equal-weight universe buy & hold",
        "final_value": round(final_value, 2),
        "return_pct": round((final_value / capital - 1) * 100, 2) if capital else 0.0,
        "equity_curve": _equity_curve(
            {symbol: frames[symbol] for symbol in valid},
            weights,
            entry_date,
            exit_date,
            capital,
        ),
    }


def _validate_entry_date(target_date: pd.Timestamp, market: str, universe: list[str]) -> None:
    date_range = get_available_date_range(market, symbols=universe)
    if date_range.get("earliest_entry") and target_date < _parse_date(date_range["earliest_entry"]):
        raise ValueError(f"Pick a date on or after {date_range['earliest_entry']}")
    if date_range.get("latest_entry") and target_date > _parse_date(date_range["latest_entry"]):
        raise ValueError(f"Pick a date on or before {date_range['latest_entry']}")


def _compare_results(auto: dict[str, Any], manual: dict[str, Any], benchmark: dict[str, Any]) -> dict[str, Any]:
    auto_return = auto["summary"]["total_return_pct"]
    manual_return = manual["summary"]["total_return_pct"]
    benchmark_return = benchmark["return_pct"]

    candidates = {
        "auto": auto_return,
        "manual": manual_return,
        "benchmark": benchmark_return,
    }
    winner = max(candidates, key=candidates.get)

    return {
        "auto_return_pct": auto_return,
        "manual_return_pct": manual_return,
        "benchmark_return_pct": benchmark_return,
        "auto_beats_manual": auto_return > manual_return,
        "auto_beats_benchmark": auto_return > benchmark_return,
        "manual_beats_benchmark": manual_return > benchmark_return,
        "auto_profit": auto["summary"]["total_profit"],
        "manual_profit": manual["summary"]["total_profit"],
        "winner": winner,
        "winner_label": {
            "auto": "System suggestion",
            "manual": "Your manual picks",
            "benchmark": "Equal-weight benchmark",
        }[winner],
    }


def run_mock_backtest(
    as_of_date: str,
    market: str = "hk",
    hold_period: str = "3mo",
    capital: float = 100_000.0,
    top_n: int = 4,
    universe_symbols: list[str] | None = None,
    manual_symbols: list[str] | None = None,
) -> dict[str, Any]:
    target_date = _parse_date(as_of_date)
    hold_days = HOLD_DAYS.get(hold_period, HOLD_DAYS["3mo"])
    universe = universe_symbols or get_universe(market)
    if not universe:
        raise ValueError("Provide at least one symbol in the universe")

    _validate_entry_date(target_date, market, universe)

    scored, frames = _build_scored_universe(universe, target_date)
    if not frames:
        raise ValueError("Not enough historical data for the selected universe")

    auto_portfolio = _build_auto_portfolio(scored, top_n=top_n)
    if not auto_portfolio:
        raise ValueError("Not enough historical data to build a portfolio for that date")

    reference_frame = next(iter(frames.values()))
    entry_date = _nearest_on_or_after(reference_frame.index, target_date)
    if entry_date is None:
        raise ValueError("Unable to find entry trading day")

    exit_date = _offset_trading_day(reference_frame.index, entry_date, hold_days)
    if exit_date is None:
        raise ValueError("Unable to find exit trading day")

    benchmark = _simulate_benchmark(universe, frames, entry_date, exit_date, capital)
    auto_result = _simulate_portfolio(auto_portfolio, frames, entry_date, exit_date, capital)
    auto_result["summary"]["benchmark_return_pct"] = benchmark["return_pct"]
    auto_result["summary"]["alpha_pct"] = round(
        auto_result["summary"]["total_return_pct"] - benchmark["return_pct"], 2
    )
    auto_result["summary"]["beat_benchmark"] = auto_result["summary"]["total_return_pct"] > benchmark["return_pct"]

    currency = "HKD" if market.lower() == "hk" else "USD"
    if market.lower() == "all":
        currency = "Mixed"
    if universe_symbols:
        currency = "Mixed"

    base = {
        "as_of_date": as_of_date,
        "entry_date": entry_date.strftime("%Y-%m-%d"),
        "exit_date": exit_date.strftime("%Y-%m-%d"),
        "hold_period": hold_period,
        "hold_days": hold_days,
        "market": market.upper(),
        "currency": currency,
        "initial_capital": capital,
        "top_n": top_n,
        "universe": universe,
        "benchmark": benchmark,
        "methodology": {
            "selection": f"Top {top_n} stocks by point-in-time technical score (RSI, MA trend, momentum)",
            "execution": "Buy at close on entry date; sell at close after hold period",
            "benchmark": "Equal-weight buy-and-hold of full scoring universe",
        },
        "scored_universe": sorted(scored, key=lambda item: item["score"], reverse=True),
    }

    if not manual_symbols:
        return {
            **base,
            "mode": "auto",
            "portfolio": auto_result["portfolio"],
            "summary": auto_result["summary"],
            "equity_curve": {
                "portfolio": auto_result["equity_curve"],
                "benchmark": benchmark["equity_curve"],
            },
        }

    manual_universe = manual_symbols
    for symbol in manual_universe:
        if symbol not in frames:
            frame = get_ohlcv(symbol)
            if frame is None or frame.empty:
                raise ValueError(f"No historical data for manual pick: {symbol}")
            frames[symbol] = frame

    manual_portfolio = _build_manual_portfolio(manual_universe, frames, target_date)
    if not manual_portfolio:
        raise ValueError("Manual picks must include symbols with data on the selected date")

    manual_result = _simulate_portfolio(manual_portfolio, frames, entry_date, exit_date, capital)
    manual_result["summary"]["benchmark_return_pct"] = benchmark["return_pct"]
    manual_result["summary"]["alpha_pct"] = round(
        manual_result["summary"]["total_return_pct"] - benchmark["return_pct"], 2
    )
    manual_result["summary"]["beat_benchmark"] = manual_result["summary"]["total_return_pct"] > benchmark["return_pct"]

    comparison = _compare_results(auto_result, manual_result, benchmark)

    return {
        **base,
        "mode": "compare",
        "portfolio": auto_result["portfolio"],
        "summary": auto_result["summary"],
        "auto": {
            "portfolio": auto_result["portfolio"],
            "summary": auto_result["summary"],
        },
        "manual": {
            "portfolio": manual_result["portfolio"],
            "summary": manual_result["summary"],
            "symbols": manual_universe,
        },
        "comparison": comparison,
        "equity_curve": {
            "portfolio": auto_result["equity_curve"],
            "manual": manual_result["equity_curve"],
            "benchmark": benchmark["equity_curve"],
        },
        "methodology": {
            **base["methodology"],
            "manual": "Equal-weight portfolio from your chosen symbols",
        },
    }
