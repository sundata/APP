"""OAuth real verification + push senders + device registration."""

import base64
import json
import time
from typing import Any
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.config import settings
from app.db import Base
from app.main import create_app
from app.models.user import User
from app.services import oauth
from app.services.auth import AuthError, jwt_encode
from app.services.push import FcmSender, PushError


def _jwt(payload: dict[str, Any], sig: str = "sig") -> str:
    def b64(o: Any) -> str:
        return base64.urlsafe_b64encode(
            json.dumps(o).encode()
        ).rstrip(b"=").decode()
    return f"{b64({'alg':'RS256','kid':'k1'})}.{b64(payload)}.{sig}"


def test_google_verify_calls_tokeninfo(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, Any] = {}

    class _Resp:
        status_code = 200
        def json(self) -> dict[str, Any]:
            return {"sub": "g1", "email": "g@x.com", "aud": "cid", "name": "G"}

    def fake_get(url: str, **kw: Any) -> Any:
        captured.update(kw)
        return _Resp()

    monkeypatch.setattr(oauth.httpx, "get", fake_get)
    claims = oauth.verify_google("tok", {"cid"})
    assert claims["sub"] == "g1"
    assert captured["params"]["id_token"] == "tok"


def test_google_verify_aud_mismatch(monkeypatch: pytest.MonkeyPatch) -> None:
    class _Resp:
        status_code = 200
        def json(self) -> dict[str, Any]:
            return {"sub": "g1", "aud": "other"}

    monkeypatch.setattr(oauth.httpx, "get", lambda *a, **k: _Resp())
    with pytest.raises(AuthError, match="aud"):
        oauth.verify_google("tok", {"cid"})


def test_apple_verify_bad_signature(monkeypatch: pytest.MonkeyPatch) -> None:
    jwks = {"keys": [{"kid": "k1", "kty": "RSA",
                      "n": "uZ-HCefFBC7dFmmg0LTp14QOADrZGRZZbXajPKmkeVY",
                      "e": "AQAB"}]}
    monkeypatch.setattr(oauth.httpx, "get", lambda *a, **k: MagicMock(json=lambda: jwks))
    tok = _jwt({"sub": "a1", "iss": "https://appleid.apple.com",
                "exp": int(time.time()) + 600})
    with pytest.raises(AuthError):
        oauth.verify_apple(tok)


def test_configured_verifier_mock_in_dev() -> None:
    v = oauth.configured_verifier()
    assert v is not None  # settings.oauth_mode == "mock" by default


# ---- push ----

def test_fcm_sender_posts(monkeypatch: pytest.MonkeyPatch) -> None:
    client = MagicMock()
    resp = MagicMock(status_code=200)
    client.post = MagicMock(return_value=resp)
    f = FcmSender("proj", get_access_token=lambda: "tok", client=client)
    f.send("dev-tok", "t", "b", {"a": 1})
    args, kwargs = client.post.call_args
    assert "projects/proj" in args[0]
    assert kwargs["json"]["message"]["token"] == "dev-tok"
    assert kwargs["headers"]["authorization"] == "Bearer tok"


def test_fcm_sender_raises_on_error() -> None:
    client = MagicMock()
    client.post = MagicMock(return_value=MagicMock(status_code=500, text="x"))
    f = FcmSender("p", get_access_token=lambda: "t", client=client)
    with pytest.raises(PushError):
        f.send("d", "t", "b", {})


# ---- device registration API ----

@pytest.fixture()
def client() -> TestClient:  # type: ignore[misc]
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    with Session(engine) as s:
        s.add(User(id="u1", email="u@x.com", provider="password"))
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


def test_device_register_and_delete(client: TestClient) -> None:
    auth = {"Authorization": f"Bearer {jwt_encode('u1', settings.secret_key)}"}
    r = client.post(
        "/api/v1/notifications/devices",
        json={"platform": "fcm", "token": "dev-abc"},
        headers=auth,
    )
    assert r.status_code == 201
    r2 = client.post(
        "/api/v1/notifications/devices",
        json={"platform": "webpush", "token": "dev-abc",
              "keys": {"p256dh": "x", "auth": "y"}},
        headers=auth,
    )
    assert r2.status_code == 201  # upserts same token
    assert (
        client.delete("/api/v1/notifications/devices/dev-abc", headers=auth).status_code
        == 204
    )
    assert (
        client.delete("/api/v1/notifications/devices/dev-abc", headers=auth).status_code
        == 404
    )
