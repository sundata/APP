"""Shared helpers for the FurinNews API (HTTP fetching, HTML parsing, DB sessions)."""

from __future__ import annotations

import re
from contextlib import contextmanager
from typing import Iterable, Iterator, Optional, Sequence
from urllib.parse import urlparse

import aiohttp

MOBILE_UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
    "AppleWebKit/605.1.15"
)
FEED_UA = "Mozilla/5.0 FeedFetcher"

_HTML_CONTENT_TYPES = ("text/html", "application/xhtml")
_TAG_RE = re.compile(r"<[^>]+>")


async def fetch_text(
    url: str,
    *,
    ua: str = MOBILE_UA,
    timeout: int = 10,
    require_ok: bool = True,
    require_html: bool = False,
    verify_ssl: bool = True,
) -> Optional[str]:
    """Fetch a URL and return its body as text, or None when it is unusable.

    Exceptions are propagated so callers can log them with their own context.
    """
    async with aiohttp.ClientSession() as session:
        async with session.get(
            url,
            headers={"User-Agent": ua},
            timeout=aiohttp.ClientTimeout(total=timeout),
            **({} if verify_ssl else {"ssl": False}),
            allow_redirects=True,
        ) as resp:
            if require_ok and resp.status != 200:
                return None
            if require_html:
                content_type = resp.headers.get("content-type", "")
                if not any(t in content_type for t in _HTML_CONTENT_TYPES):
                    return None
            return await resp.text(errors="ignore")


def find_meta_content(
    html: str,
    *,
    properties: Sequence[str] = (),
    names: Sequence[str] = (),
) -> Optional[str]:
    """Return the first matching `<meta>` content value.

    `properties` are matched against `property=` attributes and `names` against
    `name=`, in the given order, with the attribute and `content` appearing in
    either order.
    """
    for attribute, values in (("property", properties), ("name", names)):
        for value in values:
            escaped = re.escape(value)
            patterns = (
                rf'<meta[^>]+{attribute}=["\']{escaped}["\'][^>]+content=["\']([^"\']+)["\']',
                rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+{attribute}=["\']{escaped}["\']',
            )
            for pattern in patterns:
                match = re.search(pattern, html)
                if match:
                    return match.group(1)
    return None


def absolutize_url(page_url: str, url: str) -> str:
    """Turn a protocol-relative or root-relative URL into an absolute one."""
    if url.startswith("//"):
        return "https:" + url
    if url.startswith("/"):
        parsed = urlparse(page_url)
        return f"{parsed.scheme}://{parsed.netloc}{url}"
    return url


def strip_tags(value: str, limit: Optional[int] = None) -> str:
    """Remove HTML tags, optionally truncating the result."""
    text = _TAG_RE.sub("", value or "")
    return text[:limit] if limit else text


def url_matches_any(url: str, patterns: Iterable[str]) -> bool:
    """Case-insensitive substring match of a URL against known patterns."""
    if not url:
        return False
    lowered = url.lower()
    return any(pattern in lowered for pattern in patterns)


@contextmanager
def session_scope(session_factory) -> Iterator:
    """Yield a SQLAlchemy session and always close it."""
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
