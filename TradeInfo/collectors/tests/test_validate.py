import datetime
from decimal import Decimal

import pytest
from app.db import Base
from app.models.asset import Asset
from app.seed.assets import seed_assets
from app.seed.exchanges import seed_exchanges
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from collector.validate import QuoteValidationError, validate_quote

_UTC = datetime.timezone.utc
NOW = datetime.datetime(2026, 9, 11, 15, 0, tzinfo=_UTC)  # Fri 11:00 ET — NYSE open


@pytest.fixture()
def assets() -> dict:  # type: ignore[type-arg]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        s.commit()
        return {a.asset_id: a for a in s.scalars(select(Asset))}


def _q(**kw: object) -> dict:  # type: ignore[type-arg]
    base = {
        "asset_id": "crypto_btcusd",
        "symbol": "BTCUSD",
        "price": Decimal("65000"),
        "quote_ts": NOW,
        "currency": "USD",
        "source_id": "mock_market",
        "delay_minutes": 0,
    }
    base.update(kw)
    return base


def test_valid_quote_passes(assets: dict) -> None:  # type: ignore[type-arg]
    validate_quote(_q(), assets, NOW)


def test_unknown_asset(assets: dict) -> None:  # type: ignore[type-arg]
    with pytest.raises(QuoteValidationError, match="unknown_asset"):
        validate_quote(_q(asset_id="ghost"), assets, NOW)


def test_non_positive_price(assets: dict) -> None:  # type: ignore[type-arg]
    with pytest.raises(QuoteValidationError, match="non_positive_price"):
        validate_quote(_q(price=Decimal("0")), assets, NOW)


def test_currency_mismatch(assets: dict) -> None:  # type: ignore[type-arg]
    with pytest.raises(QuoteValidationError, match="currency_mismatch"):
        validate_quote(_q(currency="JPY"), assets, NOW)


def test_future_timestamp(assets: dict) -> None:  # type: ignore[type-arg]
    future = NOW + datetime.timedelta(minutes=10)
    with pytest.raises(QuoteValidationError, match="future_timestamp"):
        validate_quote(_q(quote_ts=future), assets, NOW)


def test_duplicate_tick(assets: dict) -> None:  # type: ignore[type-arg]
    last = {"price": Decimal("65000"), "quote_ts": NOW}
    with pytest.raises(QuoteValidationError, match="duplicate_tick"):
        validate_quote(_q(), assets, NOW, last=last)


def test_conflicting_tick(assets: dict) -> None:  # type: ignore[type-arg]
    last = {"price": Decimal("65100"), "quote_ts": NOW}
    with pytest.raises(QuoteValidationError, match="conflicting_tick"):
        validate_quote(_q(), assets, NOW, last=last)


def test_out_of_order_tick(assets: dict) -> None:  # type: ignore[type-arg]
    last = {"price": Decimal("65000"), "quote_ts": NOW + datetime.timedelta(minutes=1)}
    with pytest.raises(QuoteValidationError, match="stale_tick"):
        validate_quote(_q(), assets, NOW, last=last)


def test_impossible_jump(assets: dict) -> None:  # type: ignore[type-arg]
    last = {"price": Decimal("65000"), "quote_ts": NOW - datetime.timedelta(seconds=5)}
    with pytest.raises(QuoteValidationError, match="impossible_jump"):
        # +40% in one tick exceeds crypto's 30% ceiling
        validate_quote(_q(price=Decimal("91000")), assets, NOW, last=last)


def test_normal_move_passes(assets: dict) -> None:  # type: ignore[type-arg]
    last = {"price": Decimal("65000"), "quote_ts": NOW - datetime.timedelta(seconds=5)}
    validate_quote(_q(price=Decimal("65200")), assets, NOW, last=last)


def test_stale_after_close(assets: dict) -> None:  # type: ignore[type-arg]
    # stock tick timestamped 2h after last close while market closed
    close = NOW - datetime.timedelta(hours=1)
    ts = NOW + datetime.timedelta(hours=1)
    with pytest.raises(QuoteValidationError, match="stale_after_close"):
        validate_quote(
            _q(asset_id="stock_us_aapl", quote_ts=ts),
            assets,
            ts,
            market_open=False,
            last_close=close,
        )


def test_tick_at_close_is_legit(assets: dict) -> None:  # type: ignore[type-arg]
    close = NOW - datetime.timedelta(minutes=30)
    validate_quote(
        _q(asset_id="stock_us_aapl", quote_ts=close),
        assets,
        NOW,
        market_open=False,
        last_close=close,
    )
