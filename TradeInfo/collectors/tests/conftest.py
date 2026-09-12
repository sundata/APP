import pytest
from app.db import Base
from app.seed.data_sources import seed_data_sources
from sqlalchemy import create_engine
from sqlalchemy.orm import Session


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_data_sources(s)
        s.commit()
        yield s
