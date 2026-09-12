import datetime
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_session
from app.db import Base
from app.main import create_app
from app.models.alert import AlertTriggerLog, Notification, PriceAlert
from app.models.user import User
from app.seed.assets import seed_assets
from app.seed.exchanges import seed_exchanges
from app.services.alert_engine import ALERT_COOLDOWN, check_quotes

UTC = datetime.timezone.utc
NOW = datetime.datetime.now(UTC)


@pytest.fixture()
def engine_session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        s.commit()
        yield s


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


def _mk_alert(session: Session, direction: str = "above", price: str = "64000") -> PriceAlert:
    user = User(id="u1", email="u@x.com", provider="password")
    session.add(user)
    alert = PriceAlert(
        id="a1",
        user_id="u1",
        asset_id="crypto_btcusd",
        direction=direction,
        price=Decimal(price),
        channel="push",
        enabled=True,
    )
    session.add(alert)
    session.flush()
    return alert


def _tick(price: str, ts: datetime.datetime = NOW) -> dict:  # type: ignore[type-arg]
    return {"asset_id": "crypto_btcusd", "price": Decimal(price), "quote_ts": ts}


def test_engine_triggers_on_cross(engine_session: Session) -> None:
    _mk_alert(engine_session)
    n = check_quotes(engine_session, [_tick("65000")], NOW)
    engine_session.commit()
    assert n == 1
    assert engine_session.scalars(select(AlertTriggerLog)).one().triggered_price == Decimal(
        "65000"
    )
    notif = engine_session.scalars(select(Notification)).one()
    assert notif.type == "alert" and notif.user_id == "u1"


def test_engine_no_trigger_below_threshold(engine_session: Session) -> None:
    _mk_alert(engine_session, direction="above", price="70000")
    assert check_quotes(engine_session, [_tick("65000")], NOW) == 0


def test_engine_cooldown_blocks_refire(engine_session: Session) -> None:
    alert = _mk_alert(engine_session)
    alert.last_triggered_at = NOW - datetime.timedelta(minutes=30)
    assert check_quotes(engine_session, [_tick("65000")], NOW) == 0
    # past cooldown -> fires again
    assert (
        check_quotes(
            engine_session, [_tick("65000")], NOW + ALERT_COOLDOWN + datetime.timedelta(minutes=1)
        )
        == 1
    )


def test_engine_disabled_alert_ignored(engine_session: Session) -> None:
    alert = _mk_alert(engine_session)
    alert.enabled = False
    assert check_quotes(engine_session, [_tick("65000")], NOW) == 0


def test_below_direction(engine_session: Session) -> None:
    _mk_alert(engine_session, direction="below", price="60000")
    assert check_quotes(engine_session, [_tick("59000")], NOW) == 1
    assert check_quotes(engine_session, [_tick("61000")], NOW + ALERT_COOLDOWN * 2) == 0


def test_alert_crud(client: TestClient) -> None:
    auth = _auth(client)
    r = client.post(
        "/api/v1/alerts",
        json={"asset_id": "crypto_btcusd", "direction": "above", "price": "70000"},
        headers=auth,
    )
    assert r.status_code == 201
    aid = r.json()["id"]
    assert client.get("/api/v1/alerts", headers=auth).json()["items"]
    r = client.patch(f"/api/v1/alerts/{aid}", json={"enabled": False}, headers=auth)
    assert r.json()["enabled"] is False
    assert client.get(f"/api/v1/alerts/{aid}/history", headers=auth).status_code == 200
    assert client.delete(f"/api/v1/alerts/{aid}", headers=auth).status_code == 204


def test_alert_validation(client: TestClient) -> None:
    auth = _auth(client)
    bad = client.post(
        "/api/v1/alerts",
        json={"asset_id": "crypto_btcusd", "direction": "above", "price": "-1"},
        headers=auth,
    )
    assert bad.status_code == 400
    ghost = client.post(
        "/api/v1/alerts",
        json={"asset_id": "ghost", "direction": "above", "price": "1"},
        headers=auth,
    )
    assert ghost.status_code == 404


def test_alert_isolation_between_users(client: TestClient) -> None:
    a = _auth(client, "a@x.com")
    b = _auth(client, "b@x.com")
    r = client.post(
        "/api/v1/alerts",
        json={"asset_id": "crypto_btcusd", "direction": "above", "price": "1"},
        headers=a,
    )
    aid = r.json()["id"]
    assert (
        client.patch(
            f"/api/v1/alerts/{aid}", json={"enabled": False}, headers=b
        ).status_code
        == 404
    )
    assert client.delete(f"/api/v1/alerts/{aid}", headers=b).status_code == 404
