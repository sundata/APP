"""Search surface tests (§12): symbol, name, multilingual alias, identifier."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.db import Base
from app.main import create_app
from app.seed.assets import seed_assets
from app.seed.exchanges import seed_exchanges


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


def _ids(body: dict) -> list[str]:  # type: ignore[type-arg]
    return [i["asset_id"] for i in body["items"]]


def test_symbol_exact_match_first(client: TestClient) -> None:
    r = client.get("/api/v1/search", params={"q": "AAPL"})
    assert r.status_code == 200
    assert _ids(r.json())[0] == "stock_us_aapl"


def test_name_substring(client: TestClient) -> None:
    ids = _ids(client.get("/api/v1/search", params={"q": "Toyota"}).json())
    assert "stock_jp_7203" in ids


def test_multilingual_alias_zh(client: TestClient) -> None:
    ids = _ids(client.get("/api/v1/search", params={"q": "丰田汽车"}).json())
    assert "stock_jp_7203" in ids


def test_multilingual_alias_ja(client: TestClient) -> None:
    ids = _ids(client.get("/api/v1/search", params={"q": "ソニーグループ"}).json())
    assert "stock_jp_6758" in ids


def test_composite_symbol_alias(client: TestClient) -> None:
    ids = _ids(client.get("/api/v1/search", params={"q": "NASDAQ:AAPL"}).json())
    assert "stock_us_aapl" in ids


def test_isin_identifier(client: TestClient) -> None:
    ids = _ids(client.get("/api/v1/search", params={"q": "US0378331005"}).json())
    assert "stock_us_aapl" in ids


def test_empty_query_400(client: TestClient) -> None:
    r = client.get("/api/v1/search", params={"q": ""})
    assert r.status_code in (400, 422)


def test_no_results_returns_empty(client: TestClient) -> None:
    r = client.get("/api/v1/search", params={"q": "zzzqqqxxx"})
    assert r.status_code == 200 and r.json()["items"] == []


def test_rate_limit_headers_present(client: TestClient) -> None:
    r = client.get("/api/v1/search", params={"q": "apple"})
    assert "X-RateLimit-Limit" in r.headers
