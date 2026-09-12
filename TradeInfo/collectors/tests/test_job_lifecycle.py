from typing import Any, Iterable

from app.models.collector import CollectorError, CollectorJob
from app.models.data_source import DataSource
from sqlalchemy import select
from sqlalchemy.orm import Session

from collector.base import BaseCollector
from collector.http import FetchError


class OkCollector(BaseCollector):
    collector_type = "test_ok"

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        return [{"price": 1.0}, {"price": 2.0}]


class FailCollector(BaseCollector):
    collector_type = "test_fail"

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        raise FetchError("source exploded")


def test_success_records_job_and_source_state(session: Session) -> None:
    src = session.get_one(DataSource, "mock_market")
    job = OkCollector().run(session, src)
    session.commit()

    assert job.status == "success"
    assert job.items_count == 2
    assert job.finished_at is not None
    assert src.last_success_at is not None
    assert src.last_error is None


def test_failure_records_error_row_and_source_error(session: Session) -> None:
    src = session.get_one(DataSource, "mock_market")
    job = FailCollector().run(session, src)
    session.commit()

    assert job.status == "failed"
    assert job.finished_at is not None
    assert src.last_error and "source exploded" in src.last_error

    errors = session.scalars(
        select(CollectorError).where(CollectorError.job_id == job.id)
    ).all()
    assert len(errors) == 1
    assert errors[0].error_type == "FetchError"
    assert "source exploded" in errors[0].message


def test_jobs_are_queryable_by_source(session: Session) -> None:
    src = session.get_one(DataSource, "mock_market")
    OkCollector().run(session, src)
    FailCollector().run(session, src)
    session.commit()
    jobs = session.scalars(
        select(CollectorJob).where(CollectorJob.source_id == "mock_market")
    ).all()
    assert {j.status for j in jobs} == {"success", "failed"}
