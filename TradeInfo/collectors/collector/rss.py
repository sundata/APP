"""Minimal RSS 2.0 / Atom parser (stdlib only — no feedparser dep).

Output item: {title, url, summary, published_at (aware datetime or None)}.
"""

import datetime
import email.utils
import xml.etree.ElementTree as ET
from typing import Any, Optional

_UTC = datetime.timezone.utc


class FeedParseError(ValueError):
    pass


def _text(el: Optional[ET.Element]) -> str:
    return (el.text or "").strip() if el is not None else ""


def _parse_dt(raw: str) -> Optional[datetime.datetime]:
    if not raw:
        return None
    try:
        dt = email.utils.parsedate_to_datetime(raw)  # RFC822 (RSS)
    except (TypeError, ValueError):
        try:
            dt = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return None
    if dt is not None and dt.tzinfo is None:
        dt = dt.replace(tzinfo=_UTC)
    return dt


def parse_feed(xml_text: str) -> list[dict[str, Any]]:
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as e:
        raise FeedParseError(f"bad xml: {e}") from e

    items: list[dict[str, Any]] = []

    # RSS 2.0: channel/item
    for item in root.findall(".//item"):
        items.append(
            {
                "title": _text(item.find("title")),
                "url": _text(item.find("link")),
                "summary": _text(item.find("description")),
                "published_at": _parse_dt(_text(item.find("pubDate"))),
            }
        )

    # Atom: {ns}entry — namespace-agnostic wildcard
    for entry in root.findall(".//{*}entry"):
        link_el = entry.find("{*}link")
        url = link_el.get("href", "") if link_el is not None else ""
        published = _text(entry.find("{*}published")) or _text(entry.find("{*}updated"))
        items.append(
            {
                "title": _text(entry.find("{*}title")),
                "url": url,
                "summary": _text(entry.find("{*}summary"))
                or _text(entry.find("{*}content")),
                "published_at": _parse_dt(published),
            }
        )

    return [i for i in items if i["title"] and i["url"]]
