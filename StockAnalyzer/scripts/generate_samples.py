"""Generate bundled sample OHLCV data for offline/demo use."""

from __future__ import annotations

import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

SAMPLES = {
    "AAPL": {"start": 175.0, "drift": 0.0008, "vol": 0.018, "name": "Apple Inc."},
    "MSFT": {"start": 380.0, "drift": 0.0007, "vol": 0.016, "name": "Microsoft Corporation"},
    "GOOGL": {"start": 140.0, "drift": 0.0009, "vol": 0.019, "name": "Alphabet Inc."},
    "AMZN": {"start": 170.0, "drift": 0.0006, "vol": 0.021, "name": "Amazon.com, Inc."},
    "NVDA": {"start": 480.0, "drift": 0.0012, "vol": 0.028, "name": "NVIDIA Corporation"},
    "TSLA": {"start": 220.0, "drift": 0.0004, "vol": 0.032, "name": "Tesla, Inc."},
    "META": {"start": 480.0, "drift": 0.0008, "vol": 0.022, "name": "Meta Platforms, Inc."},
    "JPM": {"start": 190.0, "drift": 0.0005, "vol": 0.014, "name": "JPMorgan Chase & Co."},
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
            "currency": "USD",
            "sector": "Technology" if symbol != "JPM" else "Financial Services",
            "industry": "Consumer Electronics" if symbol == "AAPL" else "Software" if symbol == "MSFT" else "Internet Content & Information",
            "history": rows,
        }
        (OUTPUT_DIR / f"{symbol}.json").write_text(json.dumps(payload, indent=2))
        catalog[symbol] = {"name": config["name"], "file": f"{symbol}.json"}

    (OUTPUT_DIR / "catalog.json").write_text(json.dumps(catalog, indent=2))
    print(f"Wrote sample data for {len(SAMPLES)} symbols to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
