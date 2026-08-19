# HK Stock Analyzer

A mobile-friendly web app for analyzing **Hong Kong (HKEX)** and US stocks with news-driven trend analysis, buy/sell behavior signals, and technical indicators.

## Features

- **Hong Kong stocks** — Search `0700`, `0700.HK`, `9988`, etc. (HKEX tickers auto-normalized)
- **Trend & News tab** — Combines international headlines, sentiment, volume spikes, and momentum
- **Buy/sell behavior** — Volume ratio, 5-day momentum, and close-position buy pressure
- **Technical analysis** — RSI, MACD, Bollinger Bands, moving averages
- **Fundamentals & compare** — Key ratios and normalized performance charts
- **Mock Market backtest** — Pick a past date, custom stock lists, adjustable portfolio size, manual pick comparison
- **Adaptive validation** — 40-year walk-forward test; auto-tunes model weights when predictions miss
- **Mobile-ready UI** — Works in phone browsers with collapsible sidebar

## Quick start (local)

```bash
cd StockAnalyzer
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open http://localhost:8000 on your computer or phone (same Wi‑Fi).

Try HK tickers: `0700`, `9988.HK`, `0005`, `3690`

## Deploy to Hugging Face Spaces (view on your phone)

Hugging Face Spaces is the recommended way to host this app publicly and open it from your mobile browser.

1. Create a new Space at https://huggingface.co/new-space
2. Choose **Docker** as the SDK
3. Connect this GitHub repo and set the app root to `StockAnalyzer`
4. Copy the front matter from [HUGGINGFACE.md](HUGGINGFACE.md) into your Space README
5. Optional secrets in Space settings:
   - `FINNHUB_API_KEY` — live news and market data
   - `USE_DEMO_DATA=1` — force bundled demo data

Your Space URL will look like: `https://huggingface.co/spaces/yourname/hk-stock-analyzer`

Open that URL on your phone — no install required.

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/markets` | Popular US & HK tickers |
| `GET /api/trend/{symbol}` | News + behavior + technical trend score |
| `GET /api/news/{symbol}` | Headlines with sentiment |
| `GET /api/quote/{symbol}` | Live quote |
| `GET /api/history/{symbol}?period=1y` | OHLCV + indicators |
| `GET /api/fundamentals/{symbol}` | Company fundamentals |
| `GET /api/compare?symbols=0700.HK,9988.HK` | Normalized comparison |
| `GET /api/backtest/range?market=hk` | Valid historical date range |
| `GET /api/backtest?date=2025-11-01&market=hk&hold_period=3mo` | Mock market backtest |

## Mock Market backtest

1. Open **Mock Market** in the sidebar
2. Pick an entry date, market preset, **portfolio size** (top 2–8 stocks), and hold period
3. Optional: enter a **custom stock list** for the scoring universe (save/load lists in your browser)
4. Optional: enable **Compare with my manual picks** to test your own equal-weight portfolio head-to-head
5. The system scores each stock using **only data available on that date** (no look-ahead)
6. It builds a portfolio from the top signals and simulates forward returns vs an equal-weight benchmark

Supported hold periods: `1mo`, `3mo`, `6mo`, `1y`.

### API examples

```bash
# Custom universe + top 5 picks
curl "http://localhost:8000/api/backtest?date=2025-11-01&market=hk&top_n=5&symbols=0700.HK,9988.HK,0005.HK,3690.HK"

# Compare system suggestion vs manual picks
curl "http://localhost:8000/api/backtest?date=2025-11-01&market=hk&manual_symbols=0700.HK,1810.HK"

# Validate predictions over historic data and adapt weights
curl -X POST "http://localhost:8000/api/validate/run?symbol=AAPL&adapt=true"
```

## Adaptive model validation (up to 40 years)

The **Validate & adapt** button in Mock Market (or the API above):

1. Walks forward month-by-month through up to **40 years** of daily prices
2. Makes a bullish/bearish/neutral call using the trend model at each point in time
3. Compares against the **realized price move** over the next month
4. **Auto-adjusts weights** for technical, news, and behavior when predictions are wrong

Run from terminal:

```bash
cd StockAnalyzer
PYTHONPATH=. python3 scripts/run_validation.py AAPL 0700.HK
```

**News limitation:** Free APIs do not provide decades of archived headlines. Historical validation uses a **price-action news proxy** through the same keyword sentiment engine; live analysis still uses real headlines when available. Adapted weights are saved to `data/adaptive_weights.json` and used by the Trend & News tab.

## Trend scoring

The **Trend & News** score blends three factors (weights adapt after validation):

| Factor | Weight | Inputs |
|--------|--------|--------|
| Technical | 40% | RSI, moving-average crossovers |
| News | 35% | International & HK headline sentiment |
| Behavior | 25% | Volume spikes, momentum, buy pressure |

## Data sources

1. **Yahoo Finance** (default) — supports `.HK` tickers
2. **Finnhub** — when `FINNHUB_API_KEY` is set
3. **Google News RSS** — international headlines
4. **Demo samples** — bundled fallback for 8 HK + 8 US tickers

## Disclaimer

For informational purposes only — not financial advice.

## License

MIT
