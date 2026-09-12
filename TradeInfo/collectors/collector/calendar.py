"""CalendarCollector (REQUIREMENTS §19, §14).

- JsonCalendarCollector: generic JSON-event feed (official APIs) via HttpFetcher.
- MockCalendarCollector: internal source emitting a few high-impact events for
  today/tomorrow so Home "Important Events Today" (§7.2C) is exercisable.

Dedup: natural key (country, event_name, event_time_utc) — refetches update
actual/forecast/previous instead of duplicating.
"""

import datetime
import json
from typing import Any, Iterable, Optional

from app.models.data_source import DataSource
from app.models.economic_event import EconomicEvent
from sqlalchemy import select
from sqlalchemy.orm import Session

from collector.base import BaseCollector, _now
from collector.http import HttpFetcher
from collector.raw_store import RawStore

_UTC = datetime.timezone.utc

_MOCK_EVENTS = [
    ("US", "USD", "US CPI YoY", "high"),
    ("US", "USD", "FOMC Rate Decision", "high"),
    ("JP", "JPY", "BOJ Policy Statement", "high"),
    ("EU", "EUR", "ECB Rate Decision", "high"),
    ("AU", "AUD", "RBA Rate Decision", "high"),
    ("US", "USD", "Nonfarm Payrolls", "high"),
    ("CN", "CNY", "China GDP YoY", "high"),
    ("US", "USD", "MBA Mortgage Applications", "low"),
]


def _parse_dt(value: Any) -> datetime.datetime:
    if isinstance(value, datetime.datetime):
        dt = value
    elif isinstance(value, (int, float)):
        dt = datetime.datetime.fromtimestamp(value, _UTC)
    else:
        dt = datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=_UTC)
    return dt


def upsert_events(
    session: Session, source: DataSource, items: list[dict[str, Any]]
) -> int:
    written = 0
    for item in items:
        ts = _parse_dt(item["event_time"])
        key = (item["country"], item["event_name"], ts)
        row = session.scalars(
            select(EconomicEvent).where(
                EconomicEvent.country == key[0],
                EconomicEvent.event_name == key[1],
                EconomicEvent.event_time_utc == key[2],
            )
        ).first()
        if row is None:
            row = EconomicEvent(
                country=key[0],
                event_name=key[1],
                event_time_utc=key[2],
                currency=item.get("currency") or key[0],
                importance=item.get("importance", "medium"),
                source_id=source.source_id,
            )
            session.add(row)
        # latest fetch wins on figures
        row.actual = item.get("actual", row.actual)
        row.forecast = item.get("forecast", row.forecast)
        row.previous = item.get("previous", row.previous)
        if item.get("importance"):
            row.importance = item["importance"]
        if item.get("currency"):
            row.currency = item["currency"]
        written += 1
    return written


class JsonCalendarCollector(BaseCollector):
    """Generic collector for official JSON calendar APIs."""

    collector_type = "CalendarCollector"

    def __init__(
        self,
        raw_store: Optional[RawStore] = None,
        fetcher: Optional[HttpFetcher] = None,
    ) -> None:
        super().__init__(fetcher)
        self.raw_store = raw_store or RawStore()

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        if not source.base_url:
            raise ValueError(f"source {source.source_id} has no base_url")
        data = json.loads(self.fetcher.fetch_text(source.base_url))
        if not isinstance(data, list):
            raise ValueError("calendar feed must be a JSON array")
        return data

    def handle_items(
        self,
        session: Session,
        source: DataSource,
        items: list[dict[str, Any]],
    ) -> None:
        self.raw_store.write(
            "calendar", source.source_id, items, source_url=source.base_url
        )
        upsert_events(session, source, items)


class MockCalendarCollector(BaseCollector):
    """Internal dev source: emits today's high-impact events (§7.2C)."""

    collector_type = "CalendarCollector"

    def __init__(self, raw_store: Optional[RawStore] = None) -> None:
        super().__init__()
        self.raw_store = raw_store or RawStore()

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        today = _now().replace(hour=0, minute=0, second=0, microsecond=0)
        out: list[dict[str, Any]] = []
        for i, (country, ccy, name, imp) in enumerate(_MOCK_EVENTS):
            out.append(
                {
                    "country": country,
                    "currency": ccy,
                    "event_name": name,
                    "event_time": (
                        today + datetime.timedelta(hours=9 + i * 2)
                    ).isoformat(),
                    "importance": imp,
                    "forecast": "—",
                    "previous": "—",
                    "actual": None,
                }
            )
        return out

    def handle_items(
        self,
        session: Session,
        source: DataSource,
        items: list[dict[str, Any]],
    ) -> None:
        self.raw_store.write("calendar", source.source_id, items)
        upsert_events(session, source, items)
