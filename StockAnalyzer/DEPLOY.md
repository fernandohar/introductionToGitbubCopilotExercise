# Deploy HK Stock Analyzer to Hugging Face Spaces

Follow these steps to run the app online and open it on your phone.

## Before you start

You need:

- A [Hugging Face account](https://huggingface.co/join) (free)
- This GitHub repo pushed to your account (already done if you merged PR #4)

---

## Step 1 — Create a new Space

1. Open **[huggingface.co/new-space](https://huggingface.co/new-space)**
2. Fill in:
   - **Space name**: e.g. `hk-stock-analyzer`
   - **License**: MIT
   - **SDK**: choose **Docker**
3. Click **Create Space**

---

## Step 2 — Connect your GitHub repo

1. In your new Space, open **Settings** (gear icon)
2. Under **Repository**, click **Connect to GitHub**
3. Authorize Hugging Face if prompted
4. Select repository: **`fernandohar/introductionToGitbubCopilotExercise`**
5. Branch: **`main`** (or `cursor/stock-analyzer-e851` until merged)
6. Save

The root `Dockerfile` in this repo builds the app from the `StockAnalyzer/` folder automatically.

---

## Step 3 — Set the Space README (required for Docker port)

Hugging Face reads YAML settings from the Space README. Paste this into the Space **README** editor:

```yaml
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
```

Add a short description below the front matter, for example:

> Analyze Hong Kong (HKEX) and US stocks with news-driven trend analysis. Open on your phone browser.

Click **Save**.

---

## Step 4 — Optional: live market data

For live news and quotes (instead of demo fallback):

1. Get a free API key at **[finnhub.io](https://finnhub.io/)**
2. In your Space → **Settings** → **Repository secrets**
3. Add:
   - Name: `FINNHUB_API_KEY`
   - Value: your key

Rebuild happens automatically after saving secrets.

---

## Step 5 — Wait for the build

1. Open the **Logs** tab in your Space
2. Wait until you see: `Uvicorn running on http://0.0.0.0:7860`
3. Status should show **Running**

First build usually takes 2–4 minutes.

---

## Step 6 — Open on your phone

Your Space URL looks like:

```
https://huggingface.co/spaces/YOUR_USERNAME/hk-stock-analyzer
```

1. Copy that URL
2. Open it in **Safari** or **Chrome** on your phone
3. Optional: **Add to Home Screen** for an app-like icon

### Try these tickers

| Code | Company |
|------|---------|
| `0700` | Tencent |
| `9988` | Alibaba |
| `0005` | HSBC |
| `3690` | Meituan |

Tap **Trend & News** to see news sentiment and buy/sell behavior analysis.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails | Check **Logs** tab; ensure `Dockerfile` exists at repo root |
| Blank page | Confirm README front matter includes `app_port: 7860` |
| No live data | Add `FINNHUB_API_KEY` secret, or demo data is used automatically |
| Rate limits | Demo fallback activates when Yahoo Finance is unavailable |

---

## Update the app later

Push changes to your GitHub branch. Hugging Face rebuilds the Space automatically.

```bash
git push origin main
```

---

## Local test (same as Spaces)

```bash
cd StockAnalyzer
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 7860
```

Open http://localhost:7860

---

**Disclaimer:** For informational purposes only — not financial advice.
