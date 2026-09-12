import datetime

import pytest
from app.db import Base
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.seed.exchanges import seed_exchanges
from app.services.market_hours import is_market_open, last_close_utc, sessions_utc
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

_UTC = datetime.timezone.utc


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        s.commit()
        yield s


def _ex(session: Session, exchange_id: str) -> Exchange:
    return session.get_one(Exchange, exchange_id)


def test_nyse_open_during_session(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    # 2026-09-11 is a Friday; 15:00 UTC = 11:00 ET -> open
    dt = datetime.datetime(2026, 9, 11, 15, 0, tzinfo=_UTC)
    assert is_market_open(nyse, dt)


def test_nyse_closed_weekend(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    # Saturday 2026-09-12 15:00 UTC
    dt = datetime.datetime(2026, 9, 12, 15, 0, tzinfo=_UTC)
    assert not is_market_open(nyse, dt)


def test_nyse_closed_overnight(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    # 02:00 UTC = 22:00 ET previous day -> closed
    dt = datetime.datetime(2026, 9, 12, 2, 0, tzinfo=_UTC)
    assert not is_market_open(nyse, dt)


def test_tse_lunch_break_is_closed(session: Session) -> None:
    tse = _ex(session, "TSE")
    # 2026-09-11 03:00 UTC = 12:00 JST -> lunch break
    dt = datetime.datetime(2026, 9, 11, 3, 0, tzinfo=_UTC)
    assert not is_market_open(tse, dt)
    # 05:00 UTC = 14:00 JST -> afternoon session open
    assert is_market_open(tse, datetime.datetime(2026, 9, 11, 5, 0, tzinfo=_UTC))


def test_holiday_override_closes_market(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    dt = datetime.datetime(2026, 12, 25, 15, 0, tzinfo=_UTC)  # Thursday, Xmas
    cal = MarketCalendar(
        exchange_id="NYSE", date=datetime.date(2026, 12, 25), is_holiday=True
    )
    assert not is_market_open(nyse, dt, cal)


def test_special_session_override(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    # early close: 13:00 ET = 18:00 UTC
    cal = MarketCalendar(
        exchange_id="NYSE",
        date=datetime.date(2026, 11, 27),
        open_utc=datetime.datetime(2026, 11, 27, 14, 30, tzinfo=_UTC),
        close_utc=datetime.datetime(2026, 11, 27, 18, 0, tzinfo=_UTC),
    )
    assert is_market_open(
        nyse, datetime.datetime(2026, 11, 27, 17, 0, tzinfo=_UTC), cal
    )
    assert not is_market_open(
        nyse, datetime.datetime(2026, 11, 27, 19, 0, tzinfo=_UTC), cal
    )


def test_last_close_walks_back_over_weekend(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    sunday = datetime.datetime(2026, 9, 13, 12, 0, tzinfo=_UTC)
    close = last_close_utc(nyse, sunday, {})
    # Friday session close: 16:00 ET = 20:00 UTC on 2026-09-11
    assert close == datetime.datetime(2026, 9, 11, 20, 0, tzinfo=_UTC)


def test_sessions_utc_respects_dst(session: Session) -> None:
    nyse = _ex(session, "NYSE")
    # January: ET is UTC-5 -> 09:30 ET = 14:30 UTC
    jan = sessions_utc(nyse, datetime.date(2026, 1, 15))[0]
    assert jan[0] == datetime.datetime(2026, 1, 15, 14, 30, tzinfo=_UTC)
    # July: ET is UTC-4 -> 09:30 ET = 13:30 UTC
    jul = sessions_utc(nyse, datetime.date(2026, 7, 15))[0]
    assert jul[0] == datetime.datetime(2026, 7, 15, 13, 30, tzinfo=_UTC)
