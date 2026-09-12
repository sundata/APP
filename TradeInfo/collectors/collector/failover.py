"""Source failover (REQUIREMENTS §59, AC-010, T41).

run_with_fallback() tries enabled sources for a data_type in priority order.
On each failure the job/error rows are already recorded by BaseCollector.run();
we additionally fan out a system notification to admins (§46 ops alert) and
move on to the next source. Raises AllSourcesFailed if none succeed.
"""

import datetime
from typing import Callable

from app.models.alert import Notification
from app.models.collector import CollectorJob
from app.models.data_source import DataSource
from app.models.user import User
from sqlalchemy import select
from sqlalchemy.orm import Session

from collector.base import BaseCollector

_UTC = datetime.timezone.utc


class AllSourcesFailed(Exception):
    def __init__(self, data_type: str, jobs: list[CollectorJob]) -> None:
        self.data_type = data_type
        self.jobs = jobs
        super().__init__(
            f"all {len(jobs)} sources failed for data_type={data_type}"
        )


def _alert_admins(session: Session, source: DataSource, job: CollectorJob) -> None:
    """Ops alert to admin users on source failure (§46 admin monitors)."""
    admins = session.scalars(select(User).where(User.is_admin.is_(True))).all()
    for admin in admins:
        session.add(
            Notification(
                user_id=admin.id,
                type="system",
                title=f"collector source failed: {source.source_id}",
                body=f"{source.last_error or 'unknown error'} (job {job.id})",
                data={
                    "source_id": source.source_id,
                    "job_id": job.id,
                    "at": datetime.datetime.now(_UTC).isoformat(),
                },
            )
        )


def run_with_fallback(
    session: Session,
    collector_factory: Callable[[DataSource], BaseCollector],
    data_type: str = "market",
    alert_on_failure: bool = True,
) -> CollectorJob:
    """Try enabled sources for `data_type` by priority; return first success.

    collector_factory builds a collector bound to a specific source (the
    factory decides how the source config maps to a collector instance).
    """
    sources = list(
        session.scalars(
            select(DataSource)
            .where(
                DataSource.data_type == data_type,
                DataSource.enabled.is_(True),
            )
            .order_by(DataSource.priority, DataSource.source_id)
        )
    )
    jobs: list[CollectorJob] = []
    for src in sources:
        job = collector_factory(src).run(session, src)
        jobs.append(job)
        if job.status == "success":
            return job
        if alert_on_failure:
            _alert_admins(session, src, job)
    raise AllSourcesFailed(data_type, jobs)


def fallback_sources(session: Session, data_type: str) -> list[str]:
    """Ordered list of enabled fallback source ids (for admin/monitoring UI)."""
    return [
        s.source_id
        for s in session.scalars(
            select(DataSource)
            .where(
                DataSource.data_type == data_type,
                DataSource.enabled.is_(True),
            )
            .order_by(DataSource.priority, DataSource.source_id)
        )
    ]
