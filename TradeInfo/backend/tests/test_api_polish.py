"""T14-T18 checks: /markets/{category}, asset related news, news category
filter + §34 watchlist-weighted ordering."""

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
from app.models.news import News, NewsAssetRelation
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges

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
        s.add(
            MarketQuote(
                asset_id="stock_us_aapl",
                price=Decimal("250"),
                quote_ts=NOW,
                source_id="mock_market",
            )
        )
        # two news: one generic macro, one AAPL-tagged crypto
        s.add(
            News(
                id="n1", title="Fed holds rates", source="fed_press_rss",
                source_url="https://x/1", published_at=NOW,
                importance_score=20, content_hash="h1", norm_title="fed holds",
                dedup_group_id="g1", categories=["macro"],
            )
        )
        s.add(
            News(
                id="n2", title="Bitcoin ETF flows surge", source="x",
                source_url="https://x/2", published_at=NOW,
                importance_score=0, content_hash="h2", norm_title="btc etf",
                dedup_group_id="g2", categories=["crypto"],
            )
        )
        s.add(NewsAssetRelation(news_id="n2", asset_id="crypto_btcusd"))
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


def test_markets_category_stocks(client: TestClient) -> None:
    r = client.get("/api/v1/markets/stocks")
    assert r.status_code == 200
    body = r.json()
    assert body["category"] == "stocks"
    assert all(i["asset_type"] == "stock" for i in body["items"])


def test_markets_category_crypto_and_bad(client: TestClient) -> None:
    r = client.get("/api/v1/markets/crypto")
    assert all(i["asset_type"] == "crypto" for i in r.json()["items"])
    assert client.get("/api/v1/markets/foobar").status_code == 400


def test_asset_related_news_max5(client: TestClient) -> None:
    r = client.get("/api/v1/assets/crypto_btcusd")
    assert r.status_code == 200
    related = r.json()["related_news"]
    assert len(related) == 1
    assert related[0]["id"] == "n2"
    r2 = client.get("/api/v1/assets/stock_us_aapl")
    assert r2.json()["related_news"] == []


def test_news_category_filter(client: TestClient) -> None:
    r = client.get("/api/v1/news", params={"category": "crypto"})
    ids = [i["id"] for i in r.json()["items"]]
    assert ids == ["n2"]


def test_news_watchlist_boost_ordering(client: TestClient) -> None:
    # anonymous: macro news (importance 20) outranks crypto (0)
    r = client.get("/api/v1/news")
    assert [i["id"] for i in r.json()["items"]] == ["n1", "n2"]

    # authed user with BTC in watchlist: crypto item boosted +30 -> first
    reg = client.post(
        "/api/v1/auth/register", json={"email": "n@x.com", "password": "secret123"}
    ).json()
    auth = {"Authorization": f"Bearer {reg['access_token']}"}
    wid = client.get("/api/v1/watchlists", headers=auth).json()["items"][0]["id"]
    client.post(
        f"/api/v1/watchlists/{wid}/items",
        json={"asset_id": "crypto_btcusd"},
        headers=auth,
    )
    r = client.get("/api/v1/news", headers=auth)
    assert [i["id"] for i in r.json()["items"]] == ["n2", "n1"]
