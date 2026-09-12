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


def _auth(client: TestClient, email: str = "u@x.com") -> dict:  # type: ignore[type-arg]
    tok = client.post(
        "/api/v1/auth/register", json={"email": email, "password": "secret123"}
    ).json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def test_default_list_auto_created(client: TestClient) -> None:
    r = client.get("/api/v1/watchlists", headers=_auth(client))
    assert len(r.json()["items"]) == 1
    assert r.json()["items"][0]["name"] == "我的自选"


def test_crud_lifecycle(client: TestClient) -> None:
    auth = _auth(client)
    wl = client.post(
        "/api/v1/watchlists", json={"name": "美股"}, headers=auth
    ).json()
    assert wl["item_count"] == 0
    wid = wl["id"]

    client.post(
        f"/api/v1/watchlists/{wid}/items",
        json={"asset_id": "stock_us_aapl"},
        headers=auth,
    )
    client.post(
        f"/api/v1/watchlists/{wid}/items",
        json={"asset_id": "stock_us_nvda"},
        headers=auth,
    )
    r = client.get(f"/api/v1/watchlists/{wid}/items", headers=auth)
    ids = [i["asset_id"] for i in r.json()["items"]]
    assert ids == ["stock_us_aapl", "stock_us_nvda"]

    # rename
    r = client.patch(
        f"/api/v1/watchlists/{wid}", json={"name": "US Tech"}, headers=auth
    )
    assert r.json()["name"] == "US Tech"

    # reorder
    r = client.patch(
        f"/api/v1/watchlists/{wid}/items/reorder",
        json={"asset_ids": ["stock_us_nvda", "stock_us_aapl"]},
        headers=auth,
    )
    ids = [i["asset_id"] for i in r.json()["items"]]
    assert ids[0] == "stock_us_nvda"

    # delete item + list
    assert (
        client.delete(
            f"/api/v1/watchlists/{wid}/items/stock_us_aapl", headers=auth
        ).status_code
        == 204
    )
    assert (
        client.delete(f"/api/v1/watchlists/{wid}", headers=auth).status_code
        == 204
    )


def test_add_item_idempotent(client: TestClient) -> None:
    auth = _auth(client)
    wid = client.get("/api/v1/watchlists", headers=auth).json()["items"][0]["id"]
    for _ in range(2):
        client.post(
            f"/api/v1/watchlists/{wid}/items",
            json={"asset_id": "crypto_btcusd"},
            headers=auth,
        )
    r = client.get(f"/api/v1/watchlists/{wid}/items", headers=auth)
    assert len(r.json()["items"]) == 1


def test_cannot_touch_other_users_list(client: TestClient) -> None:
    auth_a = _auth(client, "a@x.com")
    auth_b = _auth(client, "b@x.com")
    wid = client.get("/api/v1/watchlists", headers=auth_a).json()["items"][0]["id"]
    assert (
        client.get(f"/api/v1/watchlists/{wid}/items", headers=auth_b).status_code
        == 404
    )
    assert (
        client.delete(f"/api/v1/watchlists/{wid}", headers=auth_b).status_code
        == 404
    )


def test_200_item_limit(client: TestClient) -> None:
    auth = _auth(client)
    wid = client.get("/api/v1/watchlists", headers=auth).json()["items"][0]["id"]
    from app.models.watchlist import WatchlistItem

    # pre-fill 200 items directly via a session would need DB access;
    # use API for a smaller sanity check of the limit path
    session_factory = client.app.dependency_overrides[get_session]
    gen = session_factory()
    s = next(gen)
    for i in range(200):
        s.add(WatchlistItem(watchlist_id=wid, asset_id=f"fake_{i}", position=i))
    s.commit()
    r = client.post(
        f"/api/v1/watchlists/{wid}/items",
        json={"asset_id": "crypto_btcusd"},
        headers=auth,
    )
    assert r.status_code == 409
