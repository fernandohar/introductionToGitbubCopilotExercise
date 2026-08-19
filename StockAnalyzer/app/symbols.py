"""Stock symbol normalization, with Hong Kong (HKEX) support."""

from __future__ import annotations

import re

HK_POPULAR = [
    {"symbol": "0700.HK", "name": "Tencent Holdings", "code": "0700"},
    {"symbol": "9988.HK", "name": "Alibaba Group", "code": "9988"},
    {"symbol": "0005.HK", "name": "HSBC Holdings", "code": "0005"},
    {"symbol": "3690.HK", "name": "Meituan", "code": "3690"},
    {"symbol": "1810.HK", "name": "Xiaomi Corporation", "code": "1810"},
    {"symbol": "9618.HK", "name": "JD.com", "code": "9618"},
    {"symbol": "0941.HK", "name": "China Mobile", "code": "0941"},
    {"symbol": "2318.HK", "name": "Ping An Insurance", "code": "2318"},
    {"symbol": "2388.HK", "name": "BOC Hong Kong (Holdings)", "code": "2388"},
    {"symbol": "0011.HK", "name": "Hang Seng Bank", "code": "0011"},
]

US_POPULAR = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "TSLA", "META", "JPM"]

_HK_CODE = re.compile(r"^(\d{1,5})(\.HK)?$", re.IGNORECASE)


def is_hk_symbol(symbol: str) -> bool:
    normalized = symbol.strip().upper()
    if normalized.endswith(".HK"):
        return True
    return bool(_HK_CODE.match(normalized))


def normalize_symbol(symbol: str) -> str:
    """Normalize user input to a Yahoo/Finnhub-compatible ticker."""
    raw = symbol.strip().upper().replace(" ", "")
    if not raw:
        return raw

    if raw.endswith(".HK"):
        code = raw[:-3]
        if code.isdigit():
            return f"{int(code):04d}.HK"
        return raw

    hk_match = _HK_CODE.match(raw)
    if hk_match and hk_match.group(1).isdigit():
        return f"{int(hk_match.group(1)):04d}.HK"

    return raw


def finnhub_symbol(symbol: str) -> str:
    """Finnhub uses the same tickers for many HK stocks on Yahoo."""
    return normalize_symbol(symbol)


def search_hk_catalog(query: str, limit: int = 10) -> list[dict[str, str]]:
    query = query.strip().upper()
    results: list[dict[str, str]] = []

    for item in HK_POPULAR:
        if (
            query in item["symbol"]
            or query in item["code"]
            or query in item["name"].upper()
        ):
            results.append(
                {
                    "symbol": item["symbol"],
                    "name": item["name"],
                    "exchange": "HKEX",
                    "type": "EQUITY",
                    "market": "HK",
                }
            )
        if len(results) >= limit:
            break

    if not results and query.isdigit():
        normalized = normalize_symbol(query)
        results.append(
            {
                "symbol": normalized,
                "name": f"HK Stock {normalized}",
                "exchange": "HKEX",
                "type": "EQUITY",
                "market": "HK",
            }
        )

    return results[:limit]
