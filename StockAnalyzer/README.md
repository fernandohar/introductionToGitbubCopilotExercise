# HK Stock Analyzer

A mobile-friendly web app for analyzing **Hong Kong (HKEX)** and US stocks with news-driven trend analysis, buy/sell behavior signals, and technical indicators.

## Features

- **Hong Kong stocks** — Search `0700`, `0700.HK`, `9988`, etc. (HKEX tickers auto-normalized)
- **Trend & News tab** — Combines international headlines, sentiment, volume spikes, and momentum
- **Buy/sell behavior** — Volume ratio, 5-day momentum, and close-position buy pressure
- **Technical analysis** — RSI, MACD, Bollinger Bands, moving averages
- **Fundamentals & compare** — Key ratios and normalized performance charts
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

## Trend scoring

The **Trend & News** score blends three factors:

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
