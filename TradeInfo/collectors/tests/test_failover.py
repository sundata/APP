import pytest
from app.db import Base
from app.models.alert import Notification
from app.models.collector import CollectorError, CollectorJob
from app.models.data_source import DataSource
from app.models.user import User
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from collector.base import BaseCollector
from collector.failover import AllSourcesFailed, fallback_sources, run_with_fallback


class _FakeCollector(BaseCollector):
    collector_type = "market"

    def __init__(self, should_fail: bool) -> None:
        super().__init__()
        self.should_fail = should_fail

    def collect(self, source: DataSource) -> list[dict]:  # type: ignore[type-arg]
        if self.should_fail:
            raise ConnectionError("source down")
        return [{"symbol": "X", "price": "1"}]


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        s.add(User(id="admin", email="a@x.com", provider="password", is_admin=True))
        for sid, prio in [("src_bad", 1), ("src_ok", 2), ("src_bad2", 3)]:
            s.add(
                DataSource(
                    source_id=sid,
                    source_name=sid,
                    data_type="market",
                    collection_type="rest_api",
                    license_status="free_public",
                    base_url="https://x",
                    terms_reviewed=True,
                    enabled=True,
                    priority=prio,
                    refresh_interval=60,
                )
            )
        s.commit()
        yield s


def test_falls_back_to_next_source(session: Session) -> None:
    jobs_run: list[str] = []

    def factory(src: DataSource) -> BaseCollector:
        jobs_run.append(src.source_id)
        return _FakeCollector(should_fail=src.source_id == "src_bad")

    job = run_with_fallback(session, factory)
    assert job.status == "success"
    assert jobs_run == ["src_bad", "src_ok"]  # priority order, skips 3rd

    # failure recorded + admin notified
    failed = session.scalars(
        select(CollectorJob).where(CollectorJob.status == "failed")
    ).one()
    assert session.scalars(
        select(CollectorError).where(CollectorError.job_id == failed.id)
    ).one()
    notif = session.scalars(select(Notification)).one()
    assert notif.type == "system" and "src_bad" in notif.title


def test_all_sources_fail_raises(session: Session) -> None:
    with pytest.raises(AllSourcesFailed) as e:
        run_with_fallback(session, lambda src: _FakeCollector(should_fail=True))
    assert len(e.value.jobs) == 3
    # every source got an error record
    assert session.scalars(select(CollectorError)).all()


def test_fallback_sources_ordering(session: Session) -> None:
    assert fallback_sources(session, "market") == ["src_bad", "src_ok", "src_bad2"]
    assert fallback_sources(session, "news") == []
