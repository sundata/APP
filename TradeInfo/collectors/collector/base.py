"""Collector base class + job lifecycle (REQUIREMENTS §19, §59, AC-010).

Subclasses implement `collect(source)` -> iterable of raw payload dicts.
`run()` owns the job bookkeeping: collector_jobs row, collector_errors rows,
data_sources.last_success_at / last_error.
"""

import datetime
from abc import ABC, abstractmethod
from typing import Any, Iterable, Optional

from app.models.collector import CollectorError, CollectorJob
from app.models.data_source import DataSource
from sqlalchemy.orm import Session

from collector.http import HttpFetcher

_UTC = datetime.timezone.utc


def _now() -> datetime.datetime:
    return datetime.datetime.now(_UTC)


class BaseCollector(ABC):
    collector_type: str = "base"

    def __init__(self, fetcher: Optional[HttpFetcher] = None) -> None:
        self.fetcher = fetcher or HttpFetcher()

    @abstractmethod
    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        """Fetch + parse raw items. Raise on source failure."""
        ...

    def handle_items(  # noqa: B027 — intentional no-op default hook
        self,
        session: Session,
        source: DataSource,
        items: list[dict[str, Any]],
    ) -> None:
        """Persist/process collected items. Default no-op; override in subclasses."""

    def run(self, session: Session, source: DataSource) -> CollectorJob:
        job = CollectorJob(
            source_id=source.source_id,
            collector_type=self.collector_type,
            status="running",
            started_at=_now(),
        )
        session.add(job)
        session.flush()
        try:
            items = list(self.collect(source))
            self.handle_items(session, source, items)
            job.status = "success"
            job.items_count = len(items)
            job.finished_at = _now()
            source.last_success_at = job.finished_at
            source.last_error = None
        except Exception as e:  # noqa: BLE001 — every failure must be recorded
            job.status = "failed"
            job.finished_at = _now()
            session.add(
                CollectorError(
                    job_id=job.id,
                    source_id=source.source_id,
                    error_type=type(e).__name__,
                    message=str(e)[:1000],
                )
            )
            source.last_error = f"{type(e).__name__}: {e}"[:500]
        return job
