import base64
import json

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.db import Base
from app.main import create_app


@pytest.fixture()
def client() -> TestClient:  # type: ignore[misc]
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)

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


def _register(client: TestClient, email: str = "u@x.com") -> dict:  # type: ignore[type-arg]
    r = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "secret123", "display_name": "U"},
    )
    assert r.status_code == 201
    return r.json()


def test_register_login_refresh_logout(client: TestClient) -> None:
    tokens = _register(client)
    assert tokens["access_token"] and tokens["refresh_token"]
    assert tokens["user"]["email"] == "u@x.com"

    r = client.post(
        "/api/v1/auth/login", json={"email": "u@x.com", "password": "secret123"}
    )
    assert r.status_code == 200 and r.json()["access_token"]

    r2 = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert r2.status_code == 200
    new_refresh = r2.json()["refresh_token"]

    # old refresh token is revoked (rotation)
    r3 = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert r3.status_code == 401

    # logout revokes the new one
    assert (
        client.post(
            "/api/v1/auth/logout", json={"refresh_token": new_refresh}
        ).status_code
        == 204
    )
    assert (
        client.post(
            "/api/v1/auth/refresh", json={"refresh_token": new_refresh}
        ).status_code
        == 401
    )


def test_login_wrong_password(client: TestClient) -> None:
    _register(client)
    r = client.post(
        "/api/v1/auth/login", json={"email": "u@x.com", "password": "wrong123"}
    )
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_duplicate_email_conflict(client: TestClient) -> None:
    _register(client)
    r = client.post(
        "/api/v1/auth/register",
        json={"email": "u@x.com", "password": "secret123"},
    )
    assert r.status_code == 409


def test_me_requires_and_accepts_token(client: TestClient) -> None:
    assert client.get("/api/v1/me").status_code == 401
    tokens = _register(client)
    r = client.get(
        "/api/v1/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert r.status_code == 200
    assert r.json()["user"]["email"] == "u@x.com"


def test_me_rejects_garbage_token(client: TestClient) -> None:
    r = client.get("/api/v1/me", headers={"Authorization": "Bearer garbage"})
    assert r.status_code == 401


def _fake_id_token(sub: str, email: str) -> str:
    def b64(o: dict) -> str:  # type: ignore[type-arg]
        return base64.urlsafe_b64encode(json.dumps(o).encode()).rstrip(b"=").decode()

    return f"{b64({'alg':'none'})}.{b64({'sub': sub, 'email': email})}.sig"


def test_oauth_creates_and_reuses_user(client: TestClient) -> None:
    tok = _fake_id_token("g-123", "oauth@x.com")
    r = client.post(
        "/api/v1/auth/oauth", json={"provider": "google", "id_token": tok}
    )
    assert r.status_code == 200
    assert r.json()["user"]["email"] == "oauth@x.com"
    # second login reuses the same user (provider+sub match)
    r2 = client.post(
        "/api/v1/auth/oauth", json={"provider": "google", "id_token": tok}
    )
    assert r2.json()["user"]["id"] == r.json()["user"]["id"]


def test_oauth_bad_provider(client: TestClient) -> None:
    r = client.post(
        "/api/v1/auth/oauth",
        json={"provider": "twitter", "id_token": _fake_id_token("x", "x@x.com")},
    )
    assert r.status_code == 401
