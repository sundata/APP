import datetime
from pathlib import Path

import httpx
import pytest
from app.db import Base
from app.models.data_source import DataSource
from app.models.news import News, NewsAssetRelation
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from collector.dedup import content_hash, normalize_title
from collector.http import HttpFetcher
from collector.news import NewsCollector
from collector.raw_store import RawStore
from collector.rss import parse_feed

_UTC = datetime.timezone.utc

RSS_FEED = """<?xml version="1.0"?>
<rss version="2.0"><channel><title>Feed A</title>
<item>
  <title>Fed keeps rates unchanged, signals patience on cuts</title>
  <link>https://a.example.com/story/1?utm=x</link>
  <description>Federal Reserve held rates steady. AAPL suppliers watch.</description>
  <pubDate>Fri, 11 Sep 2026 14:00:00 GMT</pubDate>
</item>
<item>
  <title>Toyota raises profit forecast</title>
  <link>https://a.example.com/story/2</link>
  <description>トヨタ自動車 lifted guidance.</description>
  <pubDate>Fri, 11 Sep 2026 13:00:00 GMT</pubDate>
</item>
</channel></rss>"""

# same Fed story via a second feed — different URL + trailing source tag
RSS_FEED_B = """<?xml version="1.0"?>
<rss version="2.0"><channel><title>Feed B</title>
<item>
  <title>Fed keeps rates unchanged, signals patience on cuts - WireB</title>
  <link>https://b.example.com/news/fed-rates</link>
  <description>Second take on the same story.</description>
  <pubDate>Fri, 11 Sep 2026 14:05:00 GMT</pubDate>
</item>
</channel></rss>"""

ATOM_FEED = """<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<entry>
  <title>ECB holds deposit rate</title>
  <link href="https://c.example.com/ecb/1"/>
  <summary>European Central Bank statement.</summary>
  <published>2026-09-11T12:00:00Z</published>
</entry>
</feed>"""


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


def _collector(session: Session, tmp_path: Path, feed: str = RSS_FEED):
    client = httpx.Client(
        transport=httpx.MockTransport(lambda r: httpx.Response(200, text=feed))
    )
    fetcher = HttpFetcher(client=client, rate_per_sec=1000.0, sleep=lambda s: None)
    return NewsCollector(session, raw_store=RawStore(str(tmp_path)), fetcher=fetcher)


def test_parse_rss() -> None:
    items = parse_feed(RSS_FEED)
    assert len(items) == 2
    assert items[0]["title"].startswith("Fed keeps")
    assert items[0]["published_at"].year == 2026


def test_parse_atom() -> None:
    items = parse_feed(ATOM_FEED)
    assert len(items) == 1
    assert items[0]["url"] == "https://c.example.com/ecb/1"


def test_normalize_title_strips_source_suffix() -> None:
    assert normalize_title("Fed holds rates - Reuters") == "fed holds rates"
    assert normalize_title("Toyota raises forecast") == "toyota raises forecast"


def test_collect_and_store_with_symbol_links(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "fed_press_rss")
    job = _collector(session, tmp_path).run(session, src)
    session.commit()
    assert job.status == "success" and job.items_count == 2

    news = session.scalars(select(News)).all()
    assert len(news) == 2

    # "AAPL" token + localized name "トヨタ自動車" both resolve
    rels = session.scalars(select(NewsAssetRelation)).all()
    linked = {r.asset_id for r in rels}
    assert "stock_us_aapl" in linked
    assert "stock_jp_7203" in linked

    # raw archive written under news/<source>/…
    assert list(tmp_path.glob("news/fed_press_rss/*/*/*/*/*.jsonl"))


def test_same_story_two_sources_share_group(session: Session, tmp_path: Path) -> None:
    fed = session.get_one(DataSource, "fed_press_rss")
    ecb = session.get_one(DataSource, "ecb_press_rss")
    _collector(session, tmp_path, RSS_FEED).run(session, fed)
    _collector(session, tmp_path, RSS_FEED_B).run(session, ecb)
    session.commit()

    fed_story = session.scalars(
        select(News).where(News.source == "fed_press_rss",
                         News.title.like("Fed keeps%"))
    ).one()
    wire_story = session.scalars(
        select(News).where(News.source == "ecb_press_rss",
                         News.title.like("Fed keeps%"))
    ).one()
    # AC-006: same story across sources -> one dedup group, two rows
    assert fed_story.dedup_group_id == wire_story.dedup_group_id


def test_refetch_same_url_is_idempotent(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "fed_press_rss")
    c = _collector(session, tmp_path)
    c.run(session, src)
    c.run(session, src)  # same feed again
    session.commit()
    total = session.scalar(select(func.count()).select_from(News))
    assert total == 2  # no duplicate rows


def test_breaking_scores_higher(session: Session, tmp_path: Path) -> None:
    src = session.get_one(DataSource, "fed_press_rss")
    _collector(session, tmp_path).run(session, src)
    session.commit()
    fed = session.scalars(
        select(News).where(News.title.like("Fed keeps%"))
    ).one()
    assert fed.importance_score >= 20  # "rate"-ish macro keyword hit
    assert content_hash(fed.title, fed.source_url) == fed.content_hash
