from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import Text, cast, func, select
from sqlalchemy.orm import Session

from app.api.deps import (
    decode_cursor,
    encode_cursor,
    get_optional_user,
    get_session,
    set_rate_limit_headers,
)
from app.api.errors import err
from app.models.news import News, NewsAssetRelation
from app.models.user import User
from app.models.watchlist import Watchlist, WatchlistItem
from app.schemas import NewsOut

router = APIRouter(tags=["news"])

# §34 ranking weights (breaking/base score lives on the row)
WATCHLIST_BOOST = 30


def _news_out(n: News, dedup_count: int, related: list[str]) -> dict[str, Any]:
    return NewsOut(
        id=n.id,
        title=n.title,
        summary=n.summary,
        source=n.source,
        source_url=n.source_url,
        published_at=n.published_at,
        language=n.language,
        importance_score=n.importance_score,
        dedup_count=dedup_count,
        related_assets=related,
    ).model_dump()


def _watchlist_assets(session: Session, user: Optional[User]) -> set[str]:
    if user is None:
        return set()
    return set(
        session.scalars(
            select(WatchlistItem.asset_id).where(
                WatchlistItem.watchlist_id.in_(
                    select(Watchlist.id).where(Watchlist.user_id == user.id)
                )
            )
        )
    )


@router.get("/news", response_model=None)
def list_news(
    response: Response,
    importance: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    asset_id: Optional[str] = Query(None),
    cursor: Optional[str] = Query(None),
    limit: int = Query(30, ge=1, le=100),
    session: Session = Depends(get_session),
    user: Optional[User] = Depends(get_optional_user),
) -> dict[str, Any]:
    offset = decode_cursor(cursor)
    # one representative row per dedup group (§35/AC-006 display rule)
    sub = (
        select(func.min(News.id).label("id"))
        .group_by(News.dedup_group_id)
        .subquery()
    )
    q = select(News).join(sub, News.id == sub.c.id)
    if importance == "important":
        q = q.where(News.importance_score >= 20)
    if category:
        q = q.where(cast(News.categories, Text).ilike(f'%"{category}"%'))
    if asset_id:
        q = q.where(
            News.id.in_(
                select(NewsAssetRelation.news_id).where(
                    NewsAssetRelation.asset_id == asset_id
                )
            )
        )
    # fetch extra, then apply §34 ranking (importance + watchlist boost,
    # recency tie-break) — cheap at MVP scale
    rows = list(session.scalars(q.limit(limit * 3 + offset)))
    wl_assets = _watchlist_assets(session, user)
    related_all = {
        nid: aid
        for nid, aid in session.execute(
            select(NewsAssetRelation.news_id, NewsAssetRelation.asset_id)
        )
    }
    for n in rows:
        rel = related_all.get(n.id)
        n._boost = (  # type: ignore[attr-defined]
            WATCHLIST_BOOST if rel is not None and rel in wl_assets else 0
        )
    rows.sort(
        key=lambda n: (-(n.importance_score + n._boost), -n.published_at.timestamp())  # type: ignore[attr-defined]
    )
    rows = rows[offset : offset + limit + 1]
    has_more = len(rows) > limit
    rows = rows[:limit]

    group_counts = {
        gid: cnt
        for gid, cnt in session.execute(
            select(News.dedup_group_id, func.count()).group_by(News.dedup_group_id)
        )
    }
    related_map: dict[str, list[str]] = {}
    for nid, aid in session.execute(
        select(NewsAssetRelation.news_id, NewsAssetRelation.asset_id).where(
            NewsAssetRelation.news_id.in_([n.id for n in rows])
        )
    ):
        related_map.setdefault(nid, []).append(aid)

    set_rate_limit_headers(response)
    return {
        "items": [
            _news_out(n, group_counts.get(n.dedup_group_id, 1), related_map.get(n.id, []))
            for n in rows
        ],
        "next_cursor": encode_cursor(offset + limit) if has_more else None,
    }


@router.get("/news/{news_id}", response_model=None)
def get_news(
    news_id: str,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    n = session.get(News, news_id)
    if n is None:
        return err(404, "not_found", f"news {news_id} not found")
    cnt = session.scalar(
        select(func.count())
        .select_from(News)
        .where(News.dedup_group_id == n.dedup_group_id)
    ) or 1
    related = [
        r
        for (r,) in session.execute(
            select(NewsAssetRelation.asset_id).where(
                NewsAssetRelation.news_id == news_id
            )
        )
    ]
    set_rate_limit_headers(response)
    return _news_out(n, cnt, related)
