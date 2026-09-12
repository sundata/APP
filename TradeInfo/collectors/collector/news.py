"""NewsCollector (REQUIREMENTS §19, §35).

collect(): fetch RSS/Atom via HttpFetcher (retry/ratelimit/breaker).
handle_items(): raw archive -> dedup grouping -> insert news rows +
news_asset_relations. Exact URL re-fetch is skipped; same story from a
different source joins the existing dedup_group (AC-006).
"""

import re
import uuid
from typing import Any, Iterable, Optional

from app.models.asset import Asset
from app.models.data_source import DataSource
from app.models.news import News, NewsAssetRelation
from sqlalchemy import select
from sqlalchemy.orm import Session

from collector.base import BaseCollector, _now
from collector.dedup import base_importance, categorize, find_group_id
from collector.http import HttpFetcher
from collector.raw_store import RawStore
from collector.rss import parse_feed

_TOKEN = re.compile(r"\b[A-Za-z][A-Za-z0-9.]{2,14}\b")


def _symbol_index(assets: Iterable[Asset]) -> dict[str, str]:
    """uppercase token -> asset_id; symbols with letters only (skip '7203' etc.)."""
    out: dict[str, str] = {}
    for a in assets:
        if any(c.isalpha() for c in a.symbol):
            out[a.symbol.upper()] = a.asset_id
    return out


def _related_asset_ids(
    item: dict[str, Any],
    assets: Iterable[Asset],
    sym_index: dict[str, str],
) -> set[str]:
    text = f"{item.get('title', '')} {item.get('summary', '')}"
    found = {sym_index[t] for t in _TOKEN.findall(text.upper()) if t in sym_index}
    # localized names (トヨタ / 丰田 etc.)
    for a in assets:
        for localized in (a.name_i18n or {}).values():
            if localized and localized in text:
                found.add(a.asset_id)
    return found


class NewsCollector(BaseCollector):
    collector_type = "NewsCollector"

    def __init__(
        self,
        session: Session,
        raw_store: Optional[RawStore] = None,
        fetcher: Optional[HttpFetcher] = None,
    ) -> None:
        super().__init__(fetcher)
        self.session = session
        self.raw_store = raw_store or RawStore()

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        if not source.base_url:
            raise ValueError(f"source {source.source_id} has no base_url")
        return parse_feed(self.fetcher.fetch_text(source.base_url))

    def handle_items(
        self,
        session: Session,
        source: DataSource,
        items: list[dict[str, Any]],
    ) -> None:
        self.raw_store.write(
            "news", source.source_id, items, source_url=source.base_url
        )
        assets = session.scalars(select(Asset)).all()
        sym_index = _symbol_index(assets)
        now = _now()
        for item in items:
            url = item["url"]
            # exact same article from same source already stored -> skip
            exists = session.scalars(
                select(News).where(
                    News.source == source.source_id, News.source_url == url
                )
            ).first()
            if exists is not None:
                continue

            group_id, h, _nt = find_group_id(
                session,
                title=item["title"],
                url=url,
                published_at=item.get("published_at"),
                now=now,
            )
            published = item.get("published_at") or now
            news = News(
                id=uuid.uuid4().hex,
                title=item["title"][:500],
                summary=(item.get("summary") or "")[:1000] or None,
                source=source.source_id,
                source_url=url,
                published_at=published,
                language=item.get("language") or "en",
                importance_score=base_importance(
                    item["title"], item.get("summary") or ""
                ),
                content_hash=h,
                norm_title=_nt,
                dedup_group_id=group_id,
                categories=categorize(item["title"], item.get("summary") or ""),
                source_id=source.source_id,
            )
            session.add(news)
            session.flush()
            for asset_id in _related_asset_ids(item, assets, sym_index):
                session.merge(
                    NewsAssetRelation(news_id=news.id, asset_id=asset_id)
                )
