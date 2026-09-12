"""Contract smoke tests: every api/openapi.yaml endpoint answers with the
documented shape (T12). Thin field assertions — full behavior tests live in
per-endpoint suites."""

import datetime
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.db import Base
from app.main import create_app
from app.models.market_quote import MarketQuote
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from app.seed.history import backfill_daily_bars

UTC = datetime.timezone.utc
NOW = datetime.datetime.now(UTC)


@pytest.fixture()
def client() -> TestClient:  # type: ignore[misc]
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
        backfill_daily_bars(s, days=10, asset_ids=["crypto_btcusd", "stock_us_aapl"])
        s.add(
            MarketQuote(
                asset_id="crypto_btcusd",
                price=Decimal("65000"),
                change_pct=Decimal("1.25"),
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
    return TestClient(app)


def test_healthz(client: TestClient) -> None:
    r = client.get("/api/v1/healthz")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_search(client: TestClient) -> None:
    r = client.get("/api/v1/search", params={"q": "apple"})
    assert r.status_code == 200
    ids = [i["asset_id"] for i in r.json()["items"]]
    assert "stock_us_aapl" in ids


def test_markets_quotes_shape(client: TestClient) -> None:
    r = client.get("/api/v1/markets/quotes", params={"asset_type": "crypto"})
    assert r.status_code == 200
    body = r.json()
    assert "items" in body and "next_cursor" in body
    item = next(i for i in body["items"] if i["asset_id"] == "crypto_btcusd")
    for k in ("price", "freshness", "delay_minutes", "quote_ts", "currency"):
        assert k in item
    assert item["freshness"] in ("live", "delayed", "stale", "closed", "no_data")


def test_asset_detail_and_404(client: TestClient) -> None:
    r = client.get("/api/v1/assets/stock_us_aapl")
    assert r.status_code == 200
    body = r.json()
    assert body["asset_id"] == "stock_us_aapl"
    assert isinstance(body["name_i18n"], dict)
    assert body["freshness"] in ("live", "delayed", "stale", "closed", "no_data")
    r2 = client.get("/api/v1/assets/nope")
    assert r2.status_code == 404 and r2.json()["error"]["code"] == "not_found"


def test_asset_chart(client: TestClient) -> None:
    r = client.get("/api/v1/assets/crypto_btcusd/chart", params={"range": "1W"})
    assert r.status_code == 200
    body = r.json()
    assert body["candles"] and body["range"] == "1W"
    c = body["candles"][0]
    for k in ("date", "open", "high", "low", "close", "volume"):
        assert k in c


def test_news_and_404(client: TestClient) -> None:
    r = client.get("/api/v1/news")
    assert r.status_code == 200
    assert "items" in r.json()
    assert client.get("/api/v1/news/missing").status_code == 404


def test_calendar_events(client: TestClient) -> None:
    r = client.get("/api/v1/calendar/events", params={"importance": "high"})
    assert r.status_code == 200
    assert "items" in r.json()


def test_exchanges(client: TestClient) -> None:
    r = client.get("/api/v1/exchanges")
    assert r.status_code == 200
    items = r.json()["items"]
    assert len(items) == 10
    assert all("market_open" in i for i in items)


def test_watchlist_flow(client: TestClient) -> None:
    assert client.get("/api/v1/watchlists").status_code == 401
    reg = client.post(
        "/api/v1/auth/register",
        json={"email": "w@x.com", "password": "secret123"},
    ).json()
    auth = {"Authorization": f"Bearer {reg['access_token']}"}
    r = client.get("/api/v1/watchlists", headers=auth)
    assert r.status_code == 200
    wid = r.json()["items"][0]["id"]  # auto-created default list
    r = client.get(f"/api/v1/watchlists/{wid}/items", headers=auth)
    assert r.status_code == 200 and r.json()["items"] == []
    r = client.post(
        f"/api/v1/watchlists/{wid}/items",
        json={"asset_id": "crypto_ethusd"},
        headers=auth,
    )
    assert r.status_code == 201
    assert (
        client.delete(
            f"/api/v1/watchlists/{wid}/items/crypto_ethusd", headers=auth
        ).status_code
        == 204
    )
    assert (
        client.get("/api/v1/watchlists/nope/items", headers=auth).status_code
        == 404
    )


def test_alerts_flow(client: TestClient) -> None:
    assert client.get("/api/v1/alerts").status_code == 401
    reg = client.post(
        "/api/v1/auth/register",
        json={"email": "al@x.com", "password": "secret123"},
    ).json()
    auth = {"Authorization": f"Bearer {reg['access_token']}"}
    r = client.post(
        "/api/v1/alerts",
        json={"asset_id": "crypto_btcusd", "direction": "above", "price": "70000"},
        headers=auth,
    )
    assert r.status_code == 201
    alert_id = r.json()["id"]
    r = client.patch(
        f"/api/v1/alerts/{alert_id}", json={"enabled": False}, headers=auth
    )
    assert r.status_code == 200 and r.json()["enabled"] is False
    assert (
        client.patch(
            "/api/v1/alerts/missing", json={"enabled": False}, headers=auth
        ).status_code
        == 404
    )


def test_portfolio_flow(client: TestClient) -> None:
    assert client.get("/api/v1/portfolio/holdings").status_code == 401
    reg = client.post(
        "/api/v1/auth/register",
        json={"email": "p@x.com", "password": "secret123"},
    ).json()
    auth = {"Authorization": f"Bearer {reg['access_token']}"}
    r = client.post(
        "/api/v1/portfolio/transactions",
        json={
            "asset_id": "stock_us_aapl",
            "side": "buy",
            "quantity": "10",
            "price": "230",
        },
        headers=auth,
    )
    assert r.status_code == 201
    items = client.get("/api/v1/portfolio/holdings", headers=auth).json()["items"]
    assert items and items[0]["asset_id"] == "stock_us_aapl"
    assert (
        client.post(
            "/api/v1/portfolio/transactions",
            json={
                "asset_id": "ghost",
                "side": "buy",
                "quantity": "1",
                "price": "1",
            },
            headers=auth,
        ).status_code
        == 404
    )


def test_error_envelope_shape(client: TestClient) -> None:
    r = client.get("/api/v1/assets/ghost")
    body = r.json()
    assert set(body) == {"error"}
    assert {"code", "message"} <= set(body["error"])
