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


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
