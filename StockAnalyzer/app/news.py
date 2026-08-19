"""News retrieval for stocks, including Hong Kong and international headlines."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote_plus

import httpx
import yfinance as yf

from app.providers import finnhub
from app.sentiment import score_text
from app.symbols import HK_POPULAR, is_hk_symbol, normalize_symbol

DEMO_NEWS: dict[str, list[dict[str, str]]] = {
    "0700.HK": [
        {
            "title": "Tencent gaming revenue beats expectations amid international expansion",
            "summary": "Analysts remain bullish as overseas titles drive growth.",
            "source": "Demo Markets",
        },
        {
            "title": "US-China tech policy talks lift Hong Kong internet stocks",
            "summary": "Regional sentiment improves on easing regulatory concerns.",
            "source": "Demo International",
        },
        {
            "title": "Tencent announces new AI cloud partnership in Southeast Asia",
            "summary": "Company expands enterprise services footprint.",
            "source": "Demo Asia Tech",
        },
    ],
    "9988.HK": [
        {
            "title": "Alibaba cloud division shows strong recovery in latest quarter",
            "summary": "Investors watch consumer spending trends in China.",
            "source": "Demo Markets",
        },
        {
            "title": "Cross-border e-commerce demand supports Alibaba logistics growth",
            "summary": "International sales channel gains traction.",
            "source": "Demo Trade",
        },
    ],
    "0005.HK": [
        {
            "title": "HSBC benefits from higher interest rate environment in Asia",
            "summary": "Bank shares rise on improved net interest margin outlook.",
            "source": "Demo Banking",
        },
        {
            "title": "Global banking stress tests keep focus on Hong Kong lenders",
            "summary": "Mixed sentiment as investors weigh macro risks.",
            "source": "Demo International",
        },
    ],
}


def _company_search_terms(symbol: str) -> list[str]:
    normalized = normalize_symbol(symbol)
    for item in HK_POPULAR:
        if item["symbol"] == normalized:
            return [item["name"], f"{item['name']} Hong Kong stock", f"HKEX {item['code']}"]
    return [normalized.replace(".HK", ""), f"{normalized} stock"]


def _format_news_item(
    title: str,
    summary: str,
    source: str,
    published_at: str | None = None,
    url: str | None = None,
    region: str = "international",
) -> dict[str, Any]:
    sentiment = score_text(f"{title} {summary}")
    return {
        "title": title,
        "summary": summary,
        "source": source,
        "published_at": published_at,
        "url": url,
        "region": region,
        "sentiment_score": sentiment["score"],
        "sentiment_label": sentiment["label"],
    }


def _fetch_yahoo_news(symbol: str, limit: int = 8) -> list[dict[str, Any]]:
    normalized = normalize_symbol(symbol)
    try:
        articles = yf.Ticker(normalized).news or []
    except Exception:
        return []

    items: list[dict[str, Any]] = []
    for article in articles[:limit]:
        title = article.get("title") or ""
        if not title:
            continue
        published = article.get("providerPublishTime")
        published_at = (
            datetime.fromtimestamp(published, tz=timezone.utc).isoformat()
            if published
            else None
        )
        items.append(
            _format_news_item(
                title=title,
                summary=article.get("summary") or article.get("title") or "",
                source=article.get("publisher") or "Yahoo Finance",
                published_at=published_at,
                url=article.get("link"),
                region="HK" if is_hk_symbol(normalized) else "international",
            )
        )
    return items


def _fetch_finnhub_news(symbol: str, limit: int = 8) -> list[dict[str, Any]]:
    if not finnhub.is_configured():
        return []

    normalized = normalize_symbol(symbol)
    end = datetime.now(timezone.utc).date()
    start = end - timedelta(days=30)

    try:
        data = finnhub._get(
            "/company-news",
            {"symbol": normalized, "from": start.isoformat(), "to": end.isoformat()},
        )
    except Exception:
        return []

    items: list[dict[str, Any]] = []
    for article in data[:limit]:
        title = article.get("headline") or ""
        if not title:
            continue
        items.append(
            _format_news_item(
                title=title,
                summary=article.get("summary") or title,
                source=article.get("source") or "Finnhub",
                published_at=datetime.fromtimestamp(article.get("datetime", 0), tz=timezone.utc).isoformat()
                if article.get("datetime")
                else None,
                url=article.get("url"),
                region="HK" if is_hk_symbol(normalized) else "international",
            )
        )
    return items


def _fetch_google_news_rss(query: str, region: str = "international", limit: int = 5) -> list[dict[str, Any]]:
    url = (
        "https://news.google.com/rss/search?q="
        + quote_plus(query)
        + "&hl=en-US&gl=US&ceid=US:en"
    )
    try:
        response = httpx.get(url, timeout=15.0, follow_redirects=True)
        response.raise_for_status()
        root = ET.fromstring(response.text)
    except Exception:
        return []

    items: list[dict[str, Any]] = []
    for item in root.findall(".//item")[:limit]:
        title = (item.findtext("title") or "").strip()
        if not title:
            continue
        items.append(
            _format_news_item(
                title=title,
                summary=item.findtext("description") or title,
                source=item.findtext("source") or "Google News",
                published_at=item.findtext("pubDate"),
                url=item.findtext("link"),
                region=region,
            )
        )
    return items


def _demo_news(symbol: str) -> list[dict[str, Any]]:
    normalized = normalize_symbol(symbol)
    raw_items = DEMO_NEWS.get(normalized, [])
    if not raw_items and is_hk_symbol(normalized):
        raw_items = [
            {
                "title": f"Hong Kong market update for {normalized}",
                "summary": "Demo headline covering international macro and local trading sentiment.",
                "source": "Demo HK Markets",
            }
        ]

    return [
        _format_news_item(
            title=item["title"],
            summary=item["summary"],
            source=item["source"],
            published_at=datetime.now(timezone.utc).isoformat(),
            region="HK" if is_hk_symbol(normalized) else "international",
        )
        for item in raw_items
    ]


def get_news(symbol: str, limit: int = 12) -> dict[str, Any]:
    normalized = normalize_symbol(symbol)
    items: list[dict[str, Any]] = []

    for fetcher in (_fetch_yahoo_news, _fetch_finnhub_news):
        try:
            items.extend(fetcher(normalized, limit=limit))
        except Exception:
            continue

    if len(items) < 4:
        for term in _company_search_terms(normalized)[:2]:
            items.extend(_fetch_google_news_rss(term, region="HK" if is_hk_symbol(normalized) else "international"))

    if not items:
        items = _demo_news(normalized)

    # Deduplicate by title
    seen: set[str] = set()
    unique: list[dict[str, Any]] = []
    for item in items:
        key = item["title"].lower().strip()
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
        if len(unique) >= limit:
            break

    return {
        "symbol": normalized,
        "market": "HK" if is_hk_symbol(normalized) else "US",
        "items": unique,
    }
