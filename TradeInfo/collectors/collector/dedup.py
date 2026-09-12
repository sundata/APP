"""News dedup (REQUIREMENTS §35, AC-006).

Aggregation keys: content_hash (exact: normalized title + url) and norm_title
(fuzzy-ish: lowercase, punctuation stripped, trailing " - Source" removed) with
a 48h recency window — one story across Reuters/Bloomberg/etc lands in one
dedup_group_id instead of N identical feed entries.
"""

import datetime
import hashlib
import re
import uuid
from typing import Optional

from app.models.news import News
from sqlalchemy import select
from sqlalchemy.orm import Session

DEDUP_WINDOW = datetime.timedelta(hours=48)

_WS = re.compile(r"\s+")
_NON_ALNUM = re.compile(r"[^\w\s]", re.UNICODE)
_SOURCE_SUFFIX = re.compile(r"\s+[-|–—]\s+[^-|–—]{2,40}$")


def normalize_title(title: str) -> str:
    t = _SOURCE_SUFFIX.sub("", title.strip().lower())
    t = _NON_ALNUM.sub("", t)
    return _WS.sub(" ", t).strip()


def normalize_url(url: str) -> str:
    u = url.split("?")[0].split("#")[0].rstrip("/")
    return u.lower()


def content_hash(title: str, url: str) -> str:
    key = f"{normalize_title(title)}|{normalize_url(url)}"
    return hashlib.sha256(key.encode()).hexdigest()


def find_group_id(
    session: Session,
    *,
    title: str,
    url: str,
    published_at: Optional[datetime.datetime],
    now: datetime.datetime,
) -> tuple[str, str, str]:
    """Return (dedup_group_id, content_hash, norm_title). Reuses an existing
    group when the story is already known (exact hash, or same normalized
    title within the window)."""
    h = content_hash(title, url)
    nt = normalize_title(title)

    exact = session.scalars(select(News).where(News.content_hash == h)).first()
    if exact is not None:
        return exact.dedup_group_id, h, nt

    if published_at is not None and nt:
        cutoff = published_at - DEDUP_WINDOW
        near = session.scalars(
            select(News).where(
                News.norm_title == nt,
                News.published_at >= cutoff,
                News.published_at <= published_at + DEDUP_WINDOW,
            )
        ).first()
        if near is not None:
            return near.dedup_group_id, h, nt

    return uuid.uuid4().hex, h, nt


_CATEGORIES = {
    "macro": (
        "fomc", "ecb", "boj", "rate", "cpi", "inflation", "gdp",
        "nonfarm", "payroll", "central bank", "treasury",
    ),
    "earnings": ("earnings", "revenue", "profit", "guidance", "eps", "quarter"),
    "crypto": (
        "bitcoin", "ethereum", "crypto", "btc", "eth", "blockchain",
        "binance", "coinbase",
    ),
    "company": ("acquire", "merger", "ceo", "layoff", "bankrupt", "ipo"),
}


def categorize(title: str, summary: str = "") -> list[str]:
    text = f"{title} {summary}".lower()
    return [c for c, keys in _CATEGORIES.items() if any(k in text for k in keys)]


def base_importance(title: str, summary: str = "") -> int:
    """§34 base score; watchlist/freshness weights are applied at query time."""
    text = f"{title} {summary}".lower()
    score = 0
    if any(k in text for k in ("breaking", "urgent", "flash:")):
        score += 50
    if any(
        k in text
        for k in (
            "rate decision", "rates unchanged", "rate cut", "rate hike",
            "interest rate", "cpi", "gdp", "nonfarm", "inflation",
            "fomc", "boj", "ecb",
        )
    ):
        score += 20
    return score
