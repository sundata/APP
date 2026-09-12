import datetime
import re
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.db import Base
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.seed.exchanges import EXCHANGES, seed_exchanges

MVP_EXCHANGE_IDS = {
    "NYSE", "NASDAQ", "AMEX", "TSE", "ASX", "HKEX", "SSE", "SZSE", "LSE", "EURONEXT"
}
_HHMM = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def test_seed_covers_all_mvp_exchanges(session: Session) -> None:
    assert seed_exchanges(session) == len(EXCHANGES)
    session.commit()
    ids = {e.exchange_id for e in session.scalars(select(Exchange))}
    assert ids == MVP_EXCHANGE_IDS


def test_exchange_fields_valid(session: Session) -> None:
    seed_exchanges(session)
    for e in session.scalars(select(Exchange)):
        ZoneInfo(e.timezone)  # raises if not a valid IANA tz
        assert re.fullmatch(r"[A-Z]{3}", e.currency)
        assert e.trading_weekdays
        assert all(0 <= d <= 6 for d in e.trading_weekdays)
        for start, end in e.sessions:
            assert _HHMM.match(start) and _HHMM.match(end)
            assert start < end


def test_seed_is_idempotent(session: Session) -> None:
    seed_exchanges(session)
    seed_exchanges(session)
    session.commit()
    count = session.scalar(select(func.count()).select_from(Exchange))
    assert count == len(EXCHANGES)


def test_market_calendar_accepts_sessions_and_holidays(session: Session) -> None:
    seed_exchanges(session)
    session.add_all(
        [
            MarketCalendar(
                exchange_id="NYSE",
                date=datetime.date(2026, 9, 11),
                open_utc=datetime.datetime(2026, 9, 11, 13, 30, tzinfo=datetime.timezone.utc),
                close_utc=datetime.datetime(2026, 9, 11, 20, 0, tzinfo=datetime.timezone.utc),
            ),
            MarketCalendar(
                exchange_id="NYSE",
                date=datetime.date(2026, 12, 25),
                is_holiday=True,
            ),
        ]
    )
    session.commit()
    rows = session.scalars(
        select(MarketCalendar).where(MarketCalendar.exchange_id == "NYSE")
    ).all()
    assert len(rows) == 2
    assert {r.is_holiday for r in rows} == {False, True}
