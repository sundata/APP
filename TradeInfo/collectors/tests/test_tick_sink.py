import json
import random
from pathlib import Path

import pytest
from app.db import Base
from app.models.data_source import DataSource
from app.models.market_quote import MarketQuote
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from collector.market import MockMarketCollector
from collector.raw_store import RawStore
from collector.tick_sink import JsonlTickSink


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        seed_assets(s)
        seed_data_sources(s)
        s.commit()
        yield s


def test_ticks_landed_in_jsonl_sink(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "mock_market")
    sink = JsonlTickSink(str(tmp_path))
    c = MockMarketCollector(
        session,
        raw_store=RawStore(str(tmp_path)),
        rng=random.Random(1),
        tick_sink=sink,
    )
    job = c.run(session, src)
    session.commit()
    assert job.status == "success"

    files = list(tmp_path.glob("ticks/mock_market/*.jsonl"))
    assert files, "tick sink wrote nothing"
    rows = [json.loads(line) for line in files[0].read_text().splitlines()]
    # every accepted quote produced a tick
    n_quotes = session.scalars(select(MarketQuote)).all()
    assert len(rows) == len(n_quotes)
    for r in rows:
        assert {"asset_id", "symbol", "price", "quote_ts", "source_id"} <= r.keys()


def test_sink_write_returns_count(tmp_path: Path) -> None:
    sink = JsonlTickSink(str(tmp_path))
    n = sink.write(
        [
            {
                "asset_id": "a",
                "symbol": "A",
                "price": "1.0",
                "quote_ts": "2026-09-11T00:00:00+00:00",
                "source_id": "mock_market",
            }
        ]
    )
    assert n == 1
    assert sink.write([]) == 0
