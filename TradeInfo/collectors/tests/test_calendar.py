import datetime
from pathlib import Path

import httpx
import pytest
from app.db import Base
from app.models.data_source import DataSource
from app.models.economic_event import EconomicEvent
from app.seed.data_sources import seed_data_sources
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from collector.calendar import JsonCalendarCollector, MockCalendarCollector
from collector.http import HttpFetcher
from collector.raw_store import RawStore

_UTC = datetime.timezone.utc

FEED = [
    {
        "country": "US", "currency": "USD", "event_name": "US CPI YoY",
        "event_time": "2026-09-11T12:30:00Z", "importance": "high",
        "forecast": "3.1%", "previous": "3.0%", "actual": None,
    },
    {
        "country": "JP", "currency": "JPY", "event_name": "BOJ Rate Decision",
        "event_time": "2026-09-11T03:00:00Z", "importance": "high",
        "forecast": None, "previous": "0.50%", "actual": "0.50%",
    },
]


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_data_sources(s)
        s.commit()
        yield s


def _json_collector(tmp_path: Path, feed: list) -> JsonCalendarCollector:
    import json as _json

    client = httpx.Client(
        transport=httpx.MockTransport(
            lambda r: httpx.Response(200, text=_json.dumps(feed))
        )
    )
    fetcher = HttpFetcher(client=client, rate_per_sec=1000.0, sleep=lambda s: None)
    return JsonCalendarCollector(raw_store=RawStore(str(tmp_path)), fetcher=fetcher)


def test_json_collector_stores_events(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "bls_schedule")
    job = _json_collector(tmp_path, FEED).run(session, src)
    session.commit()
    assert job.status == "success" and job.items_count == 2

    ev = session.scalars(
        select(EconomicEvent).where(EconomicEvent.event_name == "US CPI YoY")
    ).one()
    assert ev.importance == "high" and ev.forecast == "3.1%"
    assert ev.country == "US" and ev.currency == "USD"
    assert list(tmp_path.glob("calendar/bls_schedule/*/*/*/*/*.jsonl"))


def test_upsert_updates_actual_without_duplicating(
    session: Session, tmp_path: Path
) -> None:
    src = session.get_one(DataSource, "bls_schedule")
    _json_collector(tmp_path, FEED).run(session, src)
    session.commit()

    updated = [dict(FEED[0], actual="3.2%")] + FEED[1:]
    _json_collector(tmp_path, updated).run(session, src)
    session.commit()

    assert session.scalar(select(func.count()).select_from(EconomicEvent)) == 2
    ev = session.scalars(
        select(EconomicEvent).where(EconomicEvent.event_name == "US CPI YoY")
    ).one()
    assert ev.actual == "3.2%"


def test_mock_calendar_emits_today_high_impact(
    session: Session, tmp_path: Path
) -> None:
    src = session.get_one(DataSource, "mock_calendar")
    job = MockCalendarCollector(raw_store=RawStore(str(tmp_path))).run(session, src)
    session.commit()
    assert job.status == "success"

    events = session.scalars(select(EconomicEvent)).all()
    assert len(events) >= 5
    high = [e for e in events if e.importance == "high"]
    assert len(high) >= 5
    today_utc = datetime.datetime.now(_UTC).date()
    for e in events:
        ts = e.event_time_utc
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=_UTC)
        assert ts.date() == today_utc


def test_high_impact_query_matches_home_filter(
    session: Session, tmp_path: Path
) -> None:
    """§7.2C / AC-007: Today + High Impact default view."""
    src = session.get_one(DataSource, "mock_calendar")
    MockCalendarCollector(raw_store=RawStore(str(tmp_path))).run(session, src)
    session.commit()
    today_utc = datetime.datetime.now(_UTC).date()
    rows = session.scalars(
        select(EconomicEvent).where(
            EconomicEvent.importance == "high",
            EconomicEvent.event_time_utc >= datetime.datetime.combine(
                today_utc, datetime.time.min
            ),
        )
    ).all()
    assert len(rows) >= 5
