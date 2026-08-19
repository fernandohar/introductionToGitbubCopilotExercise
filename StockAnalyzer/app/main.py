"""FastAPI application for Stock Analyzer."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app import data

BASE_DIR = Path(__file__).resolve().parent.parent
STATIC_DIR = BASE_DIR / "static"

app = FastAPI(title="Stock Analyzer", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "source": data.active_source()}


@app.get("/api/search")
def search(q: str = Query(..., min_length=1), limit: int = Query(10, ge=1, le=25)) -> dict:
    return {"query": q, "results": data.search_symbols(q, limit=limit)}


@app.get("/api/markets")
def markets() -> dict:
    from app.symbols import HK_POPULAR, US_POPULAR

    return {
        "us": US_POPULAR,
        "hk": [item["symbol"] for item in HK_POPULAR],
        "hk_details": HK_POPULAR,
    }


@app.get("/api/news/{symbol}")
def news(symbol: str, limit: int = Query(12, ge=1, le=30)) -> dict:
    from app.news import get_news

    try:
        return get_news(symbol, limit=limit)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"Unable to fetch news for {symbol}") from exc


@app.get("/api/trend/{symbol}")
def trend(symbol: str, period: str = Query("6mo")) -> dict:
    from app.trend import get_trend_analysis

    try:
        return get_trend_analysis(symbol, period=period)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"Unable to analyze trend for {symbol}") from exc


@app.get("/api/quote/{symbol}")
def quote(symbol: str) -> dict:
    try:
        return data.get_quote(symbol)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"Unable to fetch quote for {symbol}") from exc


@app.get("/api/fundamentals/{symbol}")
def fundamentals(symbol: str) -> dict:
    try:
        return data.get_fundamentals(symbol)
    except Exception as exc:
        raise HTTPException(
            status_code=404, detail=f"Unable to fetch fundamentals for {symbol}"
        ) from exc


@app.get("/api/history/{symbol}")
def history(symbol: str, period: str = Query("1y")) -> dict:
    try:
        return data.get_history(symbol, period=period)
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"Unable to fetch history for {symbol}") from exc


@app.get("/api/compare")
def compare(symbols: str = Query(...), period: str = Query("1y")) -> dict:
    symbol_list = [s.strip() for s in symbols.split(",") if s.strip()]
    if len(symbol_list) < 2:
        raise HTTPException(status_code=400, detail="Provide at least two comma-separated symbols")
    try:
        return data.compare_symbols(symbol_list, period=period)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Unable to compare symbols") from exc


@app.get("/api/backtest/range")
def backtest_range(
    market: str = Query("hk"),
    symbols: str | None = Query(None, description="Comma-separated custom universe"),
) -> dict:
    from app.backtest import parse_symbol_list
    from app.history_store import get_available_date_range, get_universe

    universe = parse_symbol_list(symbols) or get_universe(market)
    return get_available_date_range(market, symbols=universe)


@app.get("/api/backtest")
def backtest(
    date: str = Query(..., description="Historical date YYYY-MM-DD"),
    market: str = Query("hk"),
    hold_period: str = Query("3mo"),
    capital: float = Query(100_000.0, ge=1000, le=10_000_000),
    top_n: int = Query(4, ge=1, le=8),
    symbols: str | None = Query(None, description="Custom comma-separated scoring universe"),
    manual_symbols: str | None = Query(None, description="Your manual picks to compare"),
) -> dict:
    from app.backtest import parse_symbol_list, run_mock_backtest

    try:
        return run_mock_backtest(
            as_of_date=date,
            market=market,
            hold_period=hold_period,
            capital=capital,
            top_n=top_n,
            universe_symbols=parse_symbol_list(symbols) or None,
            manual_symbols=parse_symbol_list(manual_symbols) or None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Backtest failed") from exc


@app.get("/api/validate/weights")
def validate_weights() -> dict:
    from app.adaptive_model import load_model_state, load_validation_metrics

    return {
        "model": load_model_state(),
        "last_validation": load_validation_metrics(),
    }


@app.post("/api/validate/run")
def validate_run(
    symbol: str = Query(...),
    adapt: bool = Query(True),
    max_steps: int | None = Query(None, ge=10, le=500),
) -> dict:
    from app.validation import run_validation

    try:
        return run_validation(symbol, adapt=adapt, max_steps=max_steps)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/validate/batch")
def validate_batch(
    symbols: str = Query("0700.HK,9988.HK,AAPL,MSFT"),
    adapt: bool = Query(True),
) -> dict:
    from app.backtest import parse_symbol_list
    from app.validation import run_validation_batch

    symbol_list = parse_symbol_list(symbols)
    if not symbol_list:
        raise HTTPException(status_code=400, detail="Provide at least one symbol")
    try:
        return run_validation_batch(symbol_list, adapt=adapt)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
