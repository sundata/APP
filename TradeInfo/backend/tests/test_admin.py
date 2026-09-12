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
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from app.services.auth import jwt_encode


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
        s.add(User(id="admin1", email="admin@x.com", provider="password", is_admin=True))
        s.add(User(id="u1", email="u@x.com", provider="password", is_admin=False))
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


def _tok(uid: str) -> dict:  # type: ignore[type-arg]
    return {"Authorization": f"Bearer {jwt_encode(uid, settings.secret_key)}"}


def test_rbac_non_admin_forbidden(client: TestClient) -> None:
    assert client.get("/api/v1/admin/sources").status_code == 401  # no token
    assert client.get("/api/v1/admin/sources", headers=_tok("u1")).status_code == 403
    r = client.get("/api/v1/admin/sources", headers=_tok("admin1"))
    assert r.status_code == 200


def test_sources_list_and_toggle(client: TestClient) -> None:
    auth = _tok("admin1")
    rows = client.get("/api/v1/admin/sources", headers=auth).json()["items"]
    assert any(r["source_id"] == "mock_market" for r in rows)

    # external source not reviewed -> enable blocked
    ext = next(r for r in rows if not r["enabled"] and r["source_id"] != "mock_market")
    r = client.post(f"/api/v1/admin/sources/{ext['source_id']}/toggle", headers=auth)
    assert r.status_code == 409  # terms_not_reviewed

    # mock_market toggles freely
    r = client.post("/api/v1/admin/sources/mock_market/toggle", headers=auth)
    assert r.json()["enabled"] is False
    r = client.post("/api/v1/admin/sources/mock_market/toggle", headers=auth)
    assert r.json()["enabled"] is True


def test_stats_and_freshness(client: TestClient) -> None:
    auth = _tok("admin1")
    stats = client.get("/api/v1/admin/stats", headers=auth).json()
    assert stats["users"] == 2 and stats["assets"] > 0
    fr = client.get("/api/v1/admin/freshness", headers=auth).json()
    assert any(i["status"] == "no_data" for i in fr["items"])


def test_jobs_and_quarantine_endpoints(client: TestClient) -> None:
    auth = _tok("admin1")
    assert client.get("/api/v1/admin/jobs", headers=auth).status_code == 200
    assert client.get("/api/v1/admin/quarantine", headers=auth).status_code == 200
