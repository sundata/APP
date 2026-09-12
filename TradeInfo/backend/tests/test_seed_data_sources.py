import pytest
from sqlalchemy import create_engine, inspect, select
from sqlalchemy.orm import Session

from app.db import Base
from app.models.data_source import DataSource
from app.seed.data_sources import SOURCES, seed_data_sources

# REQUIREMENTS §17 mandatory registry fields (+ delay_minutes per §44)
REQUIRED_FIELDS = {
    "source_id", "source_name", "base_url", "data_type", "collection_type",
    "license_status", "robots_status", "terms_reviewed", "refresh_interval",
    "delay_minutes", "priority", "enabled", "last_success_at", "last_error",
}


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def test_registry_has_all_required_fields(session: Session) -> None:
    engine = session.get_bind()
    cols = {c["name"] for c in inspect(engine).get_columns("data_sources")}
    assert REQUIRED_FIELDS <= cols


def test_compliance_gate_enabled_requires_review(session: Session) -> None:
    seed_data_sources(session)
    for src in session.scalars(select(DataSource)):
        if src.enabled:
            assert src.terms_reviewed or src.collection_type == "internal", (
                f"{src.source_id} enabled without terms review"
            )


def test_quote_sources_never_scrapers(session: Session) -> None:
    """REQUIREMENTS §17 red line: quote data must come from api/internal only."""
    seed_data_sources(session)
    for src in session.scalars(select(DataSource)):
        if src.data_type == "quote":
            assert src.collection_type in ("api", "internal"), src.source_id


def test_enabled_sources_have_valid_schedule(session: Session) -> None:
    seed_data_sources(session)
    for src in session.scalars(select(DataSource).where(DataSource.enabled)):
        assert src.refresh_interval > 0
        assert src.delay_minutes >= 0


def test_mock_source_enabled_for_dev(session: Session) -> None:
    seed_data_sources(session)
    mock = session.get(DataSource, "mock_market")
    assert mock is not None and mock.enabled and mock.collection_type == "internal"


def test_seed_is_idempotent(session: Session) -> None:
    seed_data_sources(session)
    seed_data_sources(session)
    session.commit()
    assert len(session.scalars(select(DataSource)).all()) == len(SOURCES)
