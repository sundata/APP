import json
import random
from pathlib import Path
from typing import Optional

import pytest
from app.db import Base
from app.models.asset import Asset
from app.models.data_source import DataSource
from app.models.market_quote import MarketQuote
from app.models.quarantine import QuoteQuarantine
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from collector.market import MockMarketCollector
from collector.normalize import NormalizeError, normalize_quote
from collector.raw_store import RawStore


class FakeRedis:
    def __init__(self) -> None:
        self.data: dict[str, dict[str, str]] = {}

    def hset(self, name: str, mapping: dict[str, str]) -> int:
        self.data.setdefault(name, {}).update(mapping)
        return len(mapping)


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


def _collector(session: Session, tmp_path: Path, redis: Optional[FakeRedis] = None):
    return MockMarketCollector(
        session, raw_store=RawStore(str(tmp_path)), redis=redis, rng=random.Random(42)
    )


def test_collect_emits_all_active_assets(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "mock_market")
    items = list(_collector(session, tmp_path).collect(src))
    total = session.scalar(select(func.count()).select_from(Asset))
    assert len(items) == total
    for it in items:
        for key in ("asset_id", "symbol", "price", "ts", "currency"):
            assert key in it


def test_run_persists_raw_and_quotes(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "mock_market")
    redis = FakeRedis()
    job = _collector(session, tmp_path, redis).run(session, src)
    session.commit()

    assert job.status == "success"
    assert job.items_count > 0

    # raw archive exists with §20 envelope
    raw_files = list(tmp_path.glob("market/mock_market/*/*/*/*/*.jsonl"))
    assert raw_files, "raw JSONL not written"
    rec = json.loads(raw_files[0].read_text().splitlines()[0])
    for key in ("source", "source_url", "fetched_at", "content_hash", "payload"):
        assert key in rec
    assert rec["source"] == "mock_market"

    # normalized quotes landed in PG
    q = session.get(MarketQuote, "crypto_btcusd")
    assert q is not None and q.price > 0
    assert q.source_id == "mock_market"

    # and in Redis fan-out
    assert "quote:crypto_btcusd" in redis.data
    assert float(redis.data["quote:crypto_btcusd"]["price"]) > 0


def test_invalid_items_are_quarantined(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "mock_market")

    class Bad(MockMarketCollector):
        def collect(self, source):  # type: ignore[no-untyped-def]
            yield {"asset_id": "crypto_btcusd", "symbol": "BTCUSD", "price": -5,
                   "ts": "2026-09-11T00:00:00+00:00", "currency": "USD"}
            yield {"asset_id": "nope", "symbol": "X", "price": 1,
                   "ts": "2026-09-11T00:00:00+00:00", "currency": "USD"}
            yield {"asset_id": "crypto_ethusd", "symbol": "ETHUSD", "price": 3400,
                   "ts": "2026-09-11T00:00:00+00:00", "currency": "USD"}

    c = Bad(session, raw_store=RawStore(str(tmp_path)), rng=random.Random(1))
    job = c.run(session, src)
    session.commit()

    assert job.status == "success"
    assert session.get(MarketQuote, "crypto_btcusd") is None  # price<=0 dropped
    assert session.get(MarketQuote, "nope") is None          # unknown asset dropped
    assert session.get(MarketQuote, "crypto_ethusd") is not None

    quarantined = session.scalars(select(QuoteQuarantine)).all()
    assert len(quarantined) == 2
    reasons = {q.reason.split(":")[0] for q in quarantined}
    assert reasons == {"non_positive_price", "unknown_asset"}


def test_second_run_updates_not_duplicates(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "mock_market")
    c = _collector(session, tmp_path)
    c.run(session, src)
    session.commit()
    c2 = _collector(session, tmp_path)
    c2.run(session, src)
    session.commit()
    quotes = session.scalars(
        select(MarketQuote).where(MarketQuote.asset_id == "crypto_btcusd")
    ).all()
    assert len(quotes) == 1  # upserted, not duplicated


def test_normalize_rejects_bad_payload() -> None:
    with pytest.raises(NormalizeError):
        normalize_quote({"asset_id": "x"}, "src", 0)  # missing fields
    with pytest.raises(NormalizeError):
        normalize_quote(
            {"asset_id": "x", "symbol": "x", "price": "abc",
             "ts": "2026-01-01T00:00:00Z", "currency": "USD"},
            "src",
            0,
        )
