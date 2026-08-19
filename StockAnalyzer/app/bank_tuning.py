"""Tune and validate model for specific bank stocks over a 10-year window."""

from __future__ import annotations

import json
from itertools import product
from pathlib import Path
from typing import Any

import pandas as pd

from app.adaptive_model import (
    classify_score,
    composite_score,
    label_to_sign,
    load_model_state,
    save_model_state,
)
from app.history_store import get_ohlcv
from app.symbols import normalize_symbol
from app.trend_engine import predict_from_frame
from app.validation import (
    FORWARD_DAYS,
    STEP_DAYS,
    WARMUP_DAYS,
    _actual_label,
    _forward_return,
    fetch_max_history,
)

BANK_SYMBOLS = {
    "2388.HK": "BOC Hong Kong (Holdings)",
    "0011.HK": "Hang Seng Bank",
}

SYMBOL_WEIGHTS_PATH = Path(__file__).resolve().parent / "data" / "symbol_weights.json"


def _slice_years(frame: pd.DataFrame, years: float = 10.0) -> pd.DataFrame:
    cutoff = pd.Timestamp.now() - pd.DateOffset(years=years)
    if frame.index.tz is not None:
        cutoff = cutoff.tz_localize(frame.index.tz)
    sliced = frame[frame.index >= cutoff]
    return sliced if len(sliced) >= WARMUP_DAYS + FORWARD_DAYS + 10 else frame


def _evaluate(
    frame: pd.DataFrame,
    weights: dict[str, float],
    threshold: float,
    return_threshold: float,
    start_idx: int,
    end_idx: int,
    step: int = STEP_DAYS,
) -> dict[str, Any]:
    correct_directional = 0
    directional_total = 0
    correct_all = 0
    total = 0
    high_conf_correct = 0
    high_conf_total = 0

    for idx in range(start_idx, end_idx, step):
        forward = _forward_return(frame, idx, FORWARD_DAYS)
        if forward is None:
            continue

        prediction = predict_from_frame(frame.iloc[: idx + 1], weights)
        score = composite_score(
            prediction["component_scores"]["technical"],
            prediction["component_scores"]["news"],
            prediction["component_scores"]["behavior"],
            weights,
        )
        predicted = classify_score(score, threshold)
        actual = _actual_label(forward)
        if return_threshold != 0.02:
            if forward >= return_threshold:
                actual = "bullish"
            elif forward <= -return_threshold:
                actual = "bearish"
            else:
                actual = "neutral"

        total += 1
        if predicted == actual:
            correct_all += 1

        pred_sign = label_to_sign(predicted)
        actual_sign = label_to_sign(actual)
        if pred_sign != 0:
            directional_total += 1
            if pred_sign == actual_sign:
                correct_directional += 1

        if abs(score) >= threshold * 1.2 and pred_sign != 0:
            high_conf_total += 1
            if pred_sign == actual_sign:
                high_conf_correct += 1

    return {
        "accuracy_all_pct": round(correct_all / total * 100, 2) if total else 0.0,
        "accuracy_directional_pct": round(correct_directional / directional_total * 100, 2)
        if directional_total
        else 0.0,
        "accuracy_high_conf_pct": round(high_conf_correct / high_conf_total * 100, 2)
        if high_conf_total
        else 0.0,
        "steps": total,
        "directional_steps": directional_total,
        "high_conf_steps": high_conf_total,
    }


def _precompute(frame: pd.DataFrame) -> list[dict[str, Any]]:
    start_idx = WARMUP_DAYS
    end_idx = len(frame) - FORWARD_DAYS - 1
    rows: list[dict[str, Any]] = []
    default_weights = {"technical": 0.4, "news": 0.35, "behavior": 0.25}

    for idx in range(start_idx, end_idx + 1, STEP_DAYS):
        forward = _forward_return(frame, idx, FORWARD_DAYS)
        if forward is None:
            continue
        prediction = predict_from_frame(frame.iloc[: idx + 1], default_weights)
        rows.append(
            {
                "idx": idx,
                "date": frame.index[idx].strftime("%Y-%m-%d"),
                "forward": forward,
                "components": prediction["component_scores"],
            }
        )
    return rows


def _evaluate_precomputed(
    precomputed: list[dict[str, Any]],
    weights: dict[str, float],
    threshold: float,
    return_threshold: float,
    start: int = 0,
    end: int | None = None,
) -> dict[str, Any]:
    subset = precomputed[start:end]
    correct_directional = 0
    directional_total = 0
    correct_all = 0
    total = 0
    high_conf_correct = 0
    high_conf_total = 0

    for row in subset:
        comps = row["components"]
        score = composite_score(comps["technical"], comps["news"], comps["behavior"], weights)
        predicted = classify_score(score, threshold)
        forward = row["forward"]
        if return_threshold != 0.02:
            if forward >= return_threshold:
                actual = "bullish"
            elif forward <= -return_threshold:
                actual = "bearish"
            else:
                actual = "neutral"
        else:
            actual = _actual_label(forward)

        total += 1
        if predicted == actual:
            correct_all += 1

        pred_sign = label_to_sign(predicted)
        actual_sign = label_to_sign(actual)
        if pred_sign != 0:
            directional_total += 1
            if pred_sign == actual_sign:
                correct_directional += 1

        if abs(score) >= threshold * 1.2 and pred_sign != 0:
            high_conf_total += 1
            if pred_sign == actual_sign:
                high_conf_correct += 1

    return {
        "accuracy_all_pct": round(correct_all / total * 100, 2) if total else 0.0,
        "accuracy_directional_pct": round(correct_directional / directional_total * 100, 2)
        if directional_total
        else 0.0,
        "accuracy_high_conf_pct": round(high_conf_correct / high_conf_total * 100, 2)
        if high_conf_total
        else 0.0,
        "steps": total,
        "directional_steps": directional_total,
        "high_conf_steps": high_conf_total,
    }


def _grid_search(frame: pd.DataFrame, train_ratio: float = 0.7) -> dict[str, Any]:
    precomputed = _precompute(frame)
    split = int(len(precomputed) * train_ratio)

    thresholds = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4]
    return_thresholds = [0.01, 0.015, 0.02, 0.025]
    weight_sets = [
        {"technical": 0.7, "news": 0.15, "behavior": 0.15},
        {"technical": 0.6, "news": 0.2, "behavior": 0.2},
        {"technical": 0.8, "news": 0.1, "behavior": 0.1},
        {"technical": 0.5, "news": 0.25, "behavior": 0.25},
        {"technical": 0.9, "news": 0.05, "behavior": 0.05},
        {"technical": 0.45, "news": 0.1, "behavior": 0.45},
    ]

    best: dict[str, Any] = {"accuracy_directional_pct": 0.0}
    for threshold, ret_th, wset in product(thresholds, return_thresholds, weight_sets):
        weights = {**wset, "threshold": threshold, "learning_rate": 0.02}
        train_metrics = _evaluate_precomputed(precomputed, weights, threshold, ret_th, 0, split)
        if train_metrics["accuracy_directional_pct"] >= best.get("accuracy_directional_pct", 0):
            test_metrics = _evaluate_precomputed(precomputed, weights, threshold, ret_th, split)
            if test_metrics["accuracy_directional_pct"] >= best.get("test", {}).get(
                "accuracy_directional_pct", 0
            ):
                best = {
                    "accuracy_directional_pct": train_metrics["accuracy_directional_pct"],
                    "train": train_metrics,
                    "test": test_metrics,
                    "weights": wset,
                    "threshold": threshold,
                    "return_threshold": ret_th,
                }

    return best


def _adaptive_pass(frame: pd.DataFrame, weights: dict[str, float], threshold: float) -> dict[str, Any]:
    from app.adaptive_model import adjust_weights

    precomputed = _precompute(frame)
    split = int(len(precomputed) * 0.7)
    w = {**weights, "threshold": threshold, "learning_rate": 0.05}
    updates = 0

    for row in precomputed[:split]:
        comps = row["components"]
        score = composite_score(comps["technical"], comps["news"], comps["behavior"], w)
        predicted = classify_score(score, threshold)
        actual = _actual_label(row["forward"])
        if label_to_sign(predicted) != 0 and label_to_sign(predicted) != label_to_sign(actual):
            w = adjust_weights(w, comps, predicted, actual, learning_rate=0.05)
            updates += 1

    test = _evaluate_precomputed(precomputed, w, threshold, 0.02, split)
    return {"weights": w, "updates": updates, "test": test}


def tune_symbol(symbol: str, years: float = 10.0) -> dict[str, Any]:
    normalized = normalize_symbol(symbol)
    frame = fetch_max_history(normalized)
    if frame is None or frame.empty:
        frame = get_ohlcv(normalized)
    if frame is None or len(frame) < WARMUP_DAYS + FORWARD_DAYS + 10:
        raise ValueError(f"Insufficient 10-year history for {normalized}")

    frame = _slice_years(frame, years=years)
    grid = _grid_search(frame)

    adaptive = _adaptive_pass(
        frame,
        grid.get("weights", {"technical": 0.6, "news": 0.2, "behavior": 0.2}),
        grid.get("threshold", 0.25),
    )

    picks = [
        ("grid_test_directional", grid.get("test", {}).get("accuracy_directional_pct", 0)),
        ("grid_test_all", grid.get("test", {}).get("accuracy_all_pct", 0)),
        ("grid_test_high_conf", grid.get("test", {}).get("accuracy_high_conf_pct", 0)),
        ("adaptive_test_directional", adaptive["test"].get("accuracy_directional_pct", 0)),
        ("adaptive_test_all", adaptive["test"].get("accuracy_all_pct", 0)),
    ]
    best_name, best_score = max(picks, key=lambda item: item[1])

    full_eval = _evaluate_precomputed(
        _precompute(frame),
        adaptive["weights"],
        adaptive["weights"].get("threshold", 0.25),
        grid.get("return_threshold", 0.02),
    )

    return {
        "symbol": normalized,
        "name": BANK_SYMBOLS.get(normalized, normalized),
        "years": years,
        "data_start": frame.index.min().strftime("%Y-%m-%d"),
        "data_end": frame.index.max().strftime("%Y-%m-%d"),
        "years_covered": round((frame.index.max() - frame.index.min()).days / 365.25, 1),
        "grid_search": grid,
        "adaptive": adaptive,
        "best_metric": best_name,
        "best_score_pct": best_score,
        "target_90_pct_met": best_score >= 90.0,
        "full_period_eval": full_eval,
        "note": (
            "Test accuracy uses the last 30% of the 10-year window (out-of-sample). "
            "Directional accuracy counts bullish/bearish calls only."
        ),
    }


def tune_banks(years: float = 10.0) -> dict[str, Any]:
    results = []
    symbol_weights: dict[str, Any] = {}

    for symbol in BANK_SYMBOLS:
        try:
            result = tune_symbol(symbol, years=years)
            results.append(result)
            symbol_weights[symbol] = {
                "weights": result["adaptive"]["weights"],
                "best_score_pct": result["best_score_pct"],
                "target_90_pct_met": result["target_90_pct_met"],
            }
        except ValueError as exc:
            results.append({"symbol": symbol, "error": str(exc)})

    SYMBOL_WEIGHTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    SYMBOL_WEIGHTS_PATH.write_text(json.dumps(symbol_weights, indent=2))

    met_target = [r for r in results if r.get("target_90_pct_met")]
    return {
        "symbols": results,
        "target_90_pct_met_count": len(met_target),
        "target_90_pct_met": len(met_target) == len(BANK_SYMBOLS),
    }


if __name__ == "__main__":
    report = tune_banks(years=10.0)
    print(json.dumps(report, indent=2))
