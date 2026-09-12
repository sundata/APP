import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.db import Base
from app.main import create_app
from app.models.alert import Notification
from app.models.user import User
from app.services.notifications import fanout, notify_prefs


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
        s.add(User(id="u1", email="u@x.com", provider="password", settings={}))
        s.add(
            Notification(
                user_id="u1", type="alert", title="BTC above 64000",
                body="price 65000", data={"asset_id": "crypto_btcusd"},
            )
        )
        s.add(Notification(user_id="u1", type="system", title="welcome"))
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


def _auth_u1() -> dict:  # type: ignore[type-arg]
    from app.config import settings
    from app.services.auth import jwt_encode

    return {"Authorization": f"Bearer {jwt_encode('u1', settings.secret_key)}"}


def test_list_and_mark_read(client: TestClient) -> None:
    auth = _auth_u1()

    r = client.get("/api/v1/notifications", headers=auth)
    assert r.status_code == 200
    assert r.json()["unread"] == 2
    nid = r.json()["items"][0]["id"]

    r = client.post(f"/api/v1/notifications/{nid}/read", headers=auth)
    assert r.json()["read"] is True
    assert client.get("/api/v1/notifications", headers=auth).json()["unread"] == 1

    client.post("/api/v1/notifications/read-all", headers=auth)
    assert client.get("/api/v1/notifications", headers=auth).json()["unread"] == 0


def test_prefs_roundtrip(client: TestClient) -> None:
    auth = _auth_u1()
    r = client.get("/api/v1/notifications/prefs", headers=auth)
    assert r.json()["push"] is True and r.json()["email"] is False
    r = client.put(
        "/api/v1/notifications/prefs",
        json={"alert": False},
        headers=auth,
    )
    assert r.json()["alert"] is False
    r = client.get("/api/v1/notifications/prefs", headers=auth)
    assert r.json()["alert"] is False and r.json()["push"] is True


def test_fanout_respects_prefs() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        s.add(
            User(
                id="u2", email="x@x.com", provider="password",
                settings={"notify": {"push": False}},
            )
        )
        n = Notification(user_id="u2", type="alert", title="t")
        s.add(n)
        s.commit()
        calls = []
        fanout(s, n, lambda *a: calls.append(a))
        assert calls == []  # push disabled -> no send
        assert notify_prefs(s.get(User, "u2"))["push"] is False


def test_notifications_require_auth(client: TestClient) -> None:
    assert client.get("/api/v1/notifications").status_code == 401
