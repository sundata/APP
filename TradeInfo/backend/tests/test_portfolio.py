import datetime
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db import Base
from app.models.asset import Asset  # noqa: F401 — ensure mappers loaded
from app.models.market_quote import MarketQuote
from app.models.portfolio import PortfolioTransaction
from app.models.user import User
from app.seed.assets import seed_assets
from app.seed.exchanges import seed_exchanges
from app.services.portfolio import compute_positions, remaining_quantity

UTC = datetime.timezone.utc
NOW = datetime.datetime.now(UTC)


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        s.add(User(id="u1", email="u@x.com", provider="password"))
        s.flush()
        yield s


def _tx(
    session: Session, side: str, qty: str, price: str, asset: str = "stock_us_aapl"
) -> None:
    session.add(
        PortfolioTransaction(
            id=f"tx_{side}_{qty}_{price}",
            user_id="u1",
            asset_id=asset,
            side=side,
            quantity=Decimal(qty),
            price=Decimal(price),
            transacted_at=NOW,
        )
    )
    session.flush()


def test_buy_then_position(session: Session) -> None:
    _tx(session, "buy", "10", "200")
    _tx(session, "buy", "10", "220")
    positions = compute_positions(session, "u1")
    assert len(positions) == 1
    p = positions[0]
    assert p["quantity"] == Decimal("10") + Decimal("10")
    # weighted avg cost = (10*200 + 10*220) / 20 = 210
    assert p["avg_cost"] == Decimal("210.0000")


def test_sell_reduces_position_keeps_avg(session: Session) -> None:
    _tx(session, "buy", "10", "200")
    _tx(session, "buy", "10", "220")
    _tx(session, "sell", "5", "250")
    p = compute_positions(session, "u1")[0]
    assert p["quantity"] == Decimal("15")
    assert p["avg_cost"] == Decimal("210.0000")  # weighted-avg basis unchanged


def test_sell_all_closes_position(session: Session) -> None:
    _tx(session, "buy", "10", "200")
    _tx(session, "sell", "10", "250")
    assert compute_positions(session, "u1") == []


def test_remaining_quantity(session: Session) -> None:
    _tx(session, "buy", "10", "200")
    _tx(session, "sell", "4", "210")
    assert remaining_quantity(session, "u1", "stock_us_aapl") == Decimal("6")


def test_unrealized_pnl_uses_latest_quote(session: Session) -> None:
    _tx(session, "buy", "10", "200")
    session.add(
        MarketQuote(
            asset_id="stock_us_aapl",
            price=Decimal("250"),
            quote_ts=NOW,
            source_id="mock_market",
        )
    )
    session.flush()
    p = compute_positions(session, "u1")[0]
    assert p["unrealized_pnl"] == Decimal("10") * Decimal("50")
    assert p["market_value"] == Decimal("2500")
    assert p["currency"] == "USD"  # original currency, no FX conversion
