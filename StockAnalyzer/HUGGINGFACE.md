---
title: HK Stock Analyzer
emoji: 📈
colorFrom: blue
colorTo: green
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# HK Stock Analyzer

Mobile-friendly stock analysis for **Hong Kong (HKEX)** and US markets.

## Features

- HK ticker support (`0700`, `0700.HK`, `9988.HK`, etc.)
- Trend analysis from international news + buy/sell behavior
- Technical indicators and fundamentals
- Works on phone browsers

## Secrets (optional)

Add these in **Settings → Repository secrets** on Hugging Face:

| Variable | Purpose |
|----------|---------|
| `FINNHUB_API_KEY` | Live news and market data |
| `USE_DEMO_DATA` | Set to `1` to force bundled demo data |

## Deploy from GitHub

1. Create a new [Hugging Face Space](https://huggingface.co/new-space) with **Docker** SDK
2. Connect your GitHub repository
3. Set the Space root directory to `StockAnalyzer` (or copy these files into the Space repo root)
4. Add optional secrets above
5. Open the Space URL on your phone

## Local run

```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 7860
```

## Disclaimer

For informational purposes only — not financial advice.
