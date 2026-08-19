"""Generate bundled sample OHLCV data for offline/demo use."""

from __future__ import annotations

import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

SAMPLES = {
    "AAPL": {"start": 175.0, "drift": 0.0008, "vol": 0.018, "name": "Apple Inc.", "currency": "USD", "sector": "Technology", "industry": "Consumer Electronics"},
    "MSFT": {"start": 380.0, "drift": 0.0007, "vol": 0.016, "name": "Microsoft Corporation", "currency": "USD", "sector": "Technology", "industry": "Software"},
    "GOOGL": {"start": 140.0, "drift": 0.0009, "vol": 0.019, "name": "Alphabet Inc.", "currency": "USD", "sector": "Technology", "industry": "Internet Content & Information"},
    "AMZN": {"start": 170.0, "drift": 0.0006, "vol": 0.021, "name": "Amazon.com, Inc.", "currency": "USD", "sector": "Consumer Cyclical", "industry": "Internet Retail"},
    "NVDA": {"start": 480.0, "drift": 0.0012, "vol": 0.028, "name": "NVIDIA Corporation", "currency": "USD", "sector": "Technology", "industry": "Semiconductors"},
    "TSLA": {"start": 220.0, "drift": 0.0004, "vol": 0.032, "name": "Tesla, Inc.", "currency": "USD", "sector": "Consumer Cyclical", "industry": "Auto Manufacturers"},
    "META": {"start": 480.0, "drift": 0.0008, "vol": 0.022, "name": "Meta Platforms, Inc.", "currency": "USD", "sector": "Technology", "industry": "Internet Content & Information"},
    "JPM": {"start": 190.0, "drift": 0.0005, "vol": 0.014, "name": "JPMorgan Chase & Co.", "currency": "USD", "sector": "Financial Services", "industry": "Banks"},
    "0700.HK": {"start": 380.0, "drift": 0.0007, "vol": 0.022, "name": "Tencent Holdings", "currency": "HKD", "sector": "Communication Services", "industry": "Interactive Media"},
    "9988.HK": {"start": 85.0, "drift": 0.0005, "vol": 0.025, "name": "Alibaba Group", "currency": "HKD", "sector": "Consumer Cyclical", "industry": "Internet Retail"},
    "0005.HK": {"start": 68.0, "drift": 0.0003, "vol": 0.012, "name": "HSBC Holdings", "currency": "HKD", "sector": "Financial Services", "industry": "Banks"},
    "3690.HK": {"start": 120.0, "drift": 0.0006, "vol": 0.024, "name": "Meituan", "currency": "HKD", "sector": "Consumer Cyclical", "industry": "Internet Retail"},
    "1810.HK": {"start": 18.0, "drift": 0.0008, "vol": 0.026, "name": "Xiaomi Corporation", "currency": "HKD", "sector": "Technology", "industry": "Consumer Electronics"},
    "9618.HK": {"start": 130.0, "drift": 0.0004, "vol": 0.023, "name": "JD.com", "currency": "HKD", "sector": "Consumer Cyclical", "industry": "Internet Retail"},
    "0941.HK": {"start": 72.0, "drift": 0.0003, "vol": 0.011, "name": "China Mobile", "currency": "HKD", "sector": "Communication Services", "industry": "Telecom Services"},
    "2318.HK": {"start": 42.0, "drift": 0.0004, "vol": 0.015, "name": "Ping An Insurance", "currency": "HKD", "sector": "Financial Services", "industry": "Insurance"},
}

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "samples"


def generate_series(symbol: str, config: dict, days: int = 400) -> list[dict]:
    rng = random.Random(symbol)
    price = config["start"]
    start_date = datetime.now(timezone.utc).date() - timedelta(days=days)
    rows: list[dict] = []

    for offset in range(days):
        date = start_date + timedelta(days=offset)
        if date.weekday() >= 5:
            continue

        daily_return = config["drift"] + config["vol"] * rng.gauss(0, 1)
        open_price = price
        close_price = max(1.0, price * (1 + daily_return))
        high_price = max(open_price, close_price) * (1 + abs(rng.gauss(0, 0.004)))
        low_price = min(open_price, close_price) * (1 - abs(rng.gauss(0, 0.004)))
        volume = int(20_000_000 + 10_000_000 * (0.5 + rng.random()) * (1 + abs(daily_return) * 8))

        rows.append(
            {
                "date": date.isoformat(),
                "open": round(open_price, 2),
                "high": round(high_price, 2),
                "low": round(low_price, 2),
                "close": round(close_price, 2),
                "volume": volume,
            }
        )
        price = close_price

    return rows


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    catalog: dict[str, dict] = {}

    for symbol, config in SAMPLES.items():
        rows = generate_series(symbol, config)
        payload = {
            "symbol": symbol,
            "name": config["name"],
            "currency": config.get("currency", "USD"),
            "sector": config.get("sector", "Technology"),
            "industry": config.get("industry", "General"),
            "market": "HK" if symbol.endswith(".HK") else "US",
            "history": rows,
        }
        (OUTPUT_DIR / f"{symbol}.json").write_text(json.dumps(payload, indent=2))
        catalog[symbol] = {"name": config["name"], "file": f"{symbol}.json"}

    (OUTPUT_DIR / "catalog.json").write_text(json.dumps(catalog, indent=2))
    print(f"Wrote sample data for {len(SAMPLES)} symbols to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
