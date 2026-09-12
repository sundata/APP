import random

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.db import Base
from app.models.price_history import PriceHistory
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from app.seed.history import backfill_daily_bars


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


def test_backfill_writes_daily_bars(session: Session) -> None:
    n = backfill_daily_bars(
        session,
        days=20,
        rng=random.Random(7),
        asset_ids=["crypto_btcusd", "stock_us_aapl"],
    )
    session.commit()
    assert n == 40  # 20 days x 2 assets (crypto 24/7, stock weekdays fit in 20d lookback span)


def test_ohlc_invariants(session: Session) -> None:
    backfill_daily_bars(
        session, days=10, rng=random.Random(3), asset_ids=["crypto_btcusd"]
    )
    session.commit()
    bars = session.scalars(
        select(PriceHistory).where(PriceHistory.asset_id == "crypto_btcusd")
    ).all()
    assert len(bars) == 10
    for b in bars:
        assert b.low <= b.open and b.low <= b.close
        assert b.high >= b.open and b.high >= b.close
        assert b.volume is not None and b.volume > 0


def test_stocks_skip_weekends(session: Session) -> None:
    backfill_daily_bars(
        session, days=10, rng=random.Random(5), asset_ids=["stock_us_aapl"]
    )
    session.commit()
    bars = session.scalars(
        select(PriceHistory).where(PriceHistory.asset_id == "stock_us_aapl")
    ).all()
    assert len(bars) == 10
    for b in bars:
        assert b.date.weekday() < 5  # NYSE trades Mon-Fri


def test_backfill_idempotent_upsert(session: Session) -> None:
    backfill_daily_bars(session, days=5, rng=random.Random(1), asset_ids=["crypto_btcusd"])
    session.commit()
    backfill_daily_bars(session, days=5, rng=random.Random(1), asset_ids=["crypto_btcusd"])
    session.commit()
    n = session.scalar(
        select(func.count()).select_from(PriceHistory).where(
            PriceHistory.asset_id == "crypto_btcusd"
        )
    )
    assert n == 5
