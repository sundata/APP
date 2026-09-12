"""T19: /ws/quotes snapshot->delta, ping/pong, resync, unsubscribe."""

import datetime
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.api.routes.ws as ws_mod
from app.api.deps import get_session
from app.db import Base
from app.main import create_app
from app.models.market_quote import MarketQuote
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges

UTC = datetime.timezone.utc
NOW = datetime.datetime.now(UTC)


@pytest.fixture()
def ctx():  # type: ignore[misc]
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        seed_data_sources(s)
        s.add(
            MarketQuote(
                asset_id="crypto_btcusd",
                price=Decimal("65000"),
                change_pct=Decimal("1.0"),
                quote_ts=NOW,
                source_id="mock_market",
            )
        )
        s.commit()

    def _override() -> Session:  # type: ignore[misc]
        with factory() as s:
            try:
                yield s
                s.commit()
            except Exception:
                s.rollback()
                raise

    app = create_app()
    app.dependency_overrides[get_session] = _override
    return {"client": TestClient(app), "engine": engine}


def test_subscribe_gets_snapshot(ctx: dict) -> None:  # type: ignore[type-arg]
    c = ctx["client"]
    with c.websocket_connect("/ws/quotes") as ws:
        ws.send_json({"type": "subscribe", "asset_ids": ["crypto_btcusd"]})
        msg = ws.receive_json()
        assert msg["type"] == "snapshot"
        q = msg["quotes"][0]
        assert q["asset_id"] == "crypto_btcusd" and q["price"] == "65000"
        assert q["delay_minutes"] == 0


def test_delta_on_change(ctx: dict) -> None:  # type: ignore[type-arg]
    ws_mod.POLL_SEC = 0.05  # speed up the poll loop
    c = ctx["client"]
    with c.websocket_connect("/ws/quotes") as ws:
        ws.send_json({"type": "subscribe", "asset_ids": ["crypto_btcusd"]})
        ws.receive_json()  # snapshot
        # mutate the quote -> next poll emits a delta
        with Session(ctx["engine"]) as s:
            q = s.get(MarketQuote, "crypto_btcusd")
            q.price = Decimal("66000")
            s.commit()
        ws.send_json({"type": "ping"})  # nudge the loop
        msg = ws.receive_json()
        # may get pong first then delta; consume until delta
        while msg["type"] != "delta":
            msg = ws.receive_json()
        assert msg["quotes"][0]["price"] == "66000"


def test_resync_resends_snapshot(ctx: dict) -> None:  # type: ignore[type-arg]
    c = ctx["client"]
    with c.websocket_connect("/ws/quotes") as ws:
        ws.send_json({"type": "subscribe", "asset_ids": ["crypto_btcusd"]})
        ws.receive_json()
        ws.send_json({"type": "resync"})
        msg = ws.receive_json()
        while msg["type"] != "snapshot":
            msg = ws.receive_json()
        assert msg["quotes"][0]["asset_id"] == "crypto_btcusd"


def test_unsubscribe_stops_updates(ctx: dict) -> None:  # type: ignore[type-arg]
    c = ctx["client"]
    with c.websocket_connect("/ws/quotes") as ws:
        ws.send_json({"type": "subscribe", "asset_ids": ["crypto_btcusd"]})
        ws.receive_json()
        ws.send_json({"type": "unsubscribe", "asset_ids": ["crypto_btcusd"]})
        ws.send_json({"type": "ping"})
        msg = ws.receive_json()
        assert msg["type"] == "pong"
