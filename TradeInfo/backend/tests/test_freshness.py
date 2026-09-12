import datetime
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db import Base
from app.models.asset import Asset
from app.models.data_source import DataSource
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.models.market_quote import MarketQuote
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from app.services.freshness import (
    STATUS_CLOSED,
    STATUS_DELAYED,
    STATUS_LIVE,
    STATUS_NO_DATA,
    STATUS_STALE,
    evaluate_freshness,
    freshness_for,
    stale_report,
)

UTC = datetime.timezone.utc
# Friday 2026-09-11 15:00 UTC = 11:00 ET -> NYSE open, TSE closed (midnight JST)
FRI_OPEN = datetime.datetime(2026, 9, 11, 15, 0, tzinfo=UTC)
SAT = datetime.datetime(2026, 9, 12, 15, 0, tzinfo=UTC)


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        seed_data_sources(s)
        s.commit()
        yield s


def _put_quote(
    session: Session, asset_id: str, ts: datetime.datetime, delay: int = 0
) -> None:
    session.add(
        MarketQuote(
            asset_id=asset_id,
            price=Decimal("100"),
            quote_ts=ts,
            source_id="mock_market",
            delay_minutes=delay,
        )
    )
    session.flush()


def _parts(session: Session, asset_id: str):
    asset = session.get_one(Asset, asset_id)
    quote = session.get(MarketQuote, asset_id)
    source = session.get_one(DataSource, quote.source_id) if quote else None
    exch = (
        session.get_one(Exchange, asset.exchange_id) if asset.exchange_id else None
    )
    return asset, quote, source, exch


def test_fresh_crypto_is_live(session: Session) -> None:
    _put_quote(session, "crypto_btcusd", FRI_OPEN - datetime.timedelta(seconds=5))
    r = freshness_for(*_parts(session, "crypto_btcusd"), {}, FRI_OPEN)
    assert r.status == STATUS_LIVE and r.market_open is None


def test_old_crypto_is_stale(session: Session) -> None:
    # mock_market refresh=5s -> threshold 30s; 10min old is stale even though 24/7
    _put_quote(session, "crypto_btcusd", FRI_OPEN - datetime.timedelta(minutes=10))
    r = freshness_for(*_parts(session, "crypto_btcusd"), {}, FRI_OPEN)
    assert r.status == STATUS_STALE


def test_stock_fresh_during_open_is_live(session: Session) -> None:
    _put_quote(session, "stock_us_aapl", FRI_OPEN - datetime.timedelta(seconds=10))
    r = freshness_for(*_parts(session, "stock_us_aapl"), {}, FRI_OPEN)
    assert r.status == STATUS_LIVE and r.market_open is True


def test_stock_stale_during_open(session: Session) -> None:
    _put_quote(session, "stock_us_aapl", FRI_OPEN - datetime.timedelta(minutes=5))
    r = freshness_for(*_parts(session, "stock_us_aapl"), {}, FRI_OPEN)
    assert r.status == STATUS_STALE and r.market_open is True


def test_old_quote_on_closed_market_is_closed_not_stale(session: Session) -> None:
    # Saturday: AAPL's Friday-close tick is ~19h old — expected, not stale (§39)
    _put_quote(
        session, "stock_us_aapl", datetime.datetime(2026, 9, 11, 20, 0, tzinfo=UTC)
    )
    r = freshness_for(*_parts(session, "stock_us_aapl"), {}, SAT)
    assert r.status == STATUS_CLOSED and r.market_open is False


def test_delayed_source_labels_delayed(session: Session) -> None:
    _put_quote(
        session, "stock_us_aapl", FRI_OPEN - datetime.timedelta(minutes=10), delay=15
    )
    r = freshness_for(*_parts(session, "stock_us_aapl"), {}, FRI_OPEN)
    # fresh relative to a 15m-delayed feed, but must never claim Live
    assert r.status == STATUS_DELAYED


def test_delayed_source_beyond_delay_is_stale(session: Session) -> None:
    _put_quote(
        session, "stock_us_aapl", FRI_OPEN - datetime.timedelta(minutes=20), delay=15
    )
    r = freshness_for(*_parts(session, "stock_us_aapl"), {}, FRI_OPEN)
    assert r.status == STATUS_STALE


def test_no_quote_is_no_data(session: Session) -> None:
    asset = session.get_one(Asset, "stock_us_aapl")
    exch = session.get_one(Exchange, "NYSE")
    r = freshness_for(asset, None, None, exch, {}, FRI_OPEN)
    assert r.status == STATUS_NO_DATA


def test_holiday_is_closed_not_stale(session: Session) -> None:
    xmas = datetime.datetime(2026, 12, 25, 15, 0, tzinfo=UTC)
    _put_quote(session, "stock_us_aapl", datetime.datetime(2026, 12, 24, 21, 0, tzinfo=UTC))
    cal = {
        datetime.date(2026, 12, 25): MarketCalendar(
            exchange_id="NYSE", date=datetime.date(2026, 12, 25), is_holiday=True
        )
    }
    r = freshness_for(*_parts(session, "stock_us_aapl"), cal, xmas)
    assert r.status == STATUS_CLOSED


def test_evaluate_freshness_and_stale_report(session: Session) -> None:
    _put_quote(session, "crypto_btcusd", FRI_OPEN - datetime.timedelta(seconds=5))
    _put_quote(session, "stock_us_aapl", FRI_OPEN - datetime.timedelta(minutes=30))
    results = evaluate_freshness(session, FRI_OPEN)
    by_id = {r.asset_id: r.status for r in results}
    assert by_id["crypto_btcusd"] == STATUS_LIVE
    assert by_id["stock_us_aapl"] == STATUS_STALE
    assert by_id["stock_jp_7203"] == STATUS_NO_DATA  # never quoted
    stale = {r.asset_id for r in stale_report(results)}
    assert "stock_us_aapl" in stale and "crypto_btcusd" not in stale
