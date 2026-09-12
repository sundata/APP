import datetime
from typing import Any, Union

from fastapi import APIRouter, Depends, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.asset import Asset
from app.models.price_history import PriceHistory
from app.schemas import AssetDetailOut, Candle
from app.services.freshness import freshness_for_row

router = APIRouter(tags=["assets"])
_UTC = datetime.timezone.utc

_RANGE_DAYS = {"1D": 1, "1W": 7, "1M": 30, "3M": 90, "1Y": 365}


@router.get("/assets/{asset_id}", response_model=None)
def get_asset(
    asset_id: str,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    asset = session.get(Asset, asset_id)
    if asset is None or asset.status != "active":
        return err(404, "not_found", f"asset {asset_id} not found")
    from app.models.market_quote import MarketQuote

    quote = session.get(MarketQuote, asset_id)
    f = freshness_for_row(session, asset, quote, datetime.datetime.now(_UTC))
    set_rate_limit_headers(response)
    out = AssetDetailOut(
        asset_id=asset.asset_id,
        symbol=asset.symbol,
        name=asset.name,
        name_i18n=asset.name_i18n or {},
        asset_type=asset.asset_type,
        exchange_id=asset.exchange_id,
        currency=asset.currency,
        latest_price=str(quote.price) if quote else None,
        change_pct=str(quote.change_pct) if quote and quote.change_pct is not None else None,
        freshness=f.status,
        is_watchlisted=False,
    ).model_dump()
    # §9 related news, one per dedup group, max 5 (T15)
    from app.models.news import News, NewsAssetRelation

    related = list(
        session.scalars(
            select(News)
            .join(
                NewsAssetRelation, News.id == NewsAssetRelation.news_id
            )
            .where(NewsAssetRelation.asset_id == asset_id)
            .order_by(News.published_at.desc())
            .limit(5)
        )
    )
    out["related_news"] = [
        {
            "id": n.id,
            "title": n.title,
            "source": n.source,
            "source_url": n.source_url,
            "published_at": n.published_at.isoformat()
            if n.published_at
            else None,
            "importance_score": n.importance_score,
        }
        for n in related
    ]
    return out


@router.get("/assets/{asset_id}/chart", response_model=None)
def get_asset_chart(
    asset_id: str,
    response: Response,
    range: str = Query("1M"),  # noqa: A002 — contract name
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    if session.get(Asset, asset_id) is None:
        return err(404, "not_found", f"asset {asset_id} not found")
    days = _RANGE_DAYS.get(range, 30)
    since = datetime.datetime.now(_UTC).date() - datetime.timedelta(days=days)
    bars = session.scalars(
        select(PriceHistory)
        .where(PriceHistory.asset_id == asset_id, PriceHistory.date >= since)
        .order_by(PriceHistory.date)
    ).all()
    set_rate_limit_headers(response)
    return {
        "asset_id": asset_id,
        "range": range,
        "candles": [
            Candle(
                date=b.date,
                open=str(b.open),
                high=str(b.high),
                low=str(b.low),
                close=str(b.close),
                volume=str(b.volume) if b.volume is not None else None,
            ).model_dump()
            for b in bars
        ],
    }
