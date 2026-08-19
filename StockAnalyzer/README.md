# Stock Analyzer

A web-based stock analysis tool with live market data, technical indicators, fundamentals, and multi-symbol comparison.

## Features

- **Live quotes** — Current price, daily change, and company name
- **Interactive charts** — Price with SMA overlays, volume, RSI, MACD, and Bollinger Bands
- **Trading signals** — Simple rule-based bullish/bearish/neutral outlook from RSI and moving-average trends
- **Fundamentals** — P/E, market cap, sector, 52-week range, and more
- **Watchlist** — Save symbols locally in your browser
- **Compare** — Normalized performance chart for up to 5 symbols
- **Resilient data layer** — Yahoo Finance with automatic demo fallback; optional Finnhub API

## Quick start

```bash
cd StockAnalyzer
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open [http://localhost:8000](http://localhost:8000) in your browser.

The app ships with bundled demo data for popular tickers (`AAPL`, `MSFT`, `GOOGL`, `AMZN`, `NVDA`, `TSLA`, `META`, `JPM`) and falls back to it automatically when Yahoo Finance is unavailable.

### Optional: live Finnhub data

```bash
export FINNHUB_API_KEY=your_key_here
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Get a free key at [finnhub.io](https://finnhub.io/).

### Force demo mode

```bash
export USE_DEMO_DATA=1
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Health check + active data source |
| `GET /api/search?q=AAPL` | Search tickers |
| `GET /api/quote/{symbol}` | Live quote |
| `GET /api/history/{symbol}?period=1y` | OHLCV + indicators |
| `GET /api/fundamentals/{symbol}` | Company fundamentals |
| `GET /api/compare?symbols=AAPL,MSFT&period=1y` | Normalized comparison |

Supported periods: `1mo`, `3mo`, `6mo`, `1y`, `2y`, `5y`, `max`.

## Data sources

1. **Yahoo Finance** (default) via `yfinance`
2. **Finnhub** when `FINNHUB_API_KEY` is set
3. **Demo samples** bundled under `data/samples/` as fallback

Data is for informational purposes only — not financial advice.

## Project structure

```
StockAnalyzer/
├── app/
│   ├── main.py          # FastAPI routes
│   ├── data.py          # Provider orchestration
│   ├── analysis.py      # Technical indicators
│   ├── serializers.py   # Response formatting
│   └── providers/
│       ├── demo.py      # Bundled sample data
│       └── finnhub.py   # Optional live API
├── data/samples/        # Generated OHLCV JSON
├── static/              # Web UI
├── scripts/
│   └── generate_samples.py
└── requirements.txt
```

Regenerate demo data:

```bash
python scripts/generate_samples.py
```

## License

MIT
