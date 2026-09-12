import datetime
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import decode_cursor, encode_cursor, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.asset import Asset
from app.models.market_quote import MarketQuote
from app.schemas import QuoteOut
from app.services.freshness import freshness_for_row

router = APIRouter(tags=["markets"])
_UTC = datetime.timezone.utc


def _quote_out(
    session: Session,
    asset: Asset,
    quote: Optional[MarketQuote],
    now: datetime.datetime,
) -> dict[str, Any]:
    f = freshness_for_row(session, asset, quote, now)
    return QuoteOut(
        asset_id=asset.asset_id,
        symbol=asset.symbol,
        name=asset.name,
        asset_type=asset.asset_type,
        price=str(quote.price) if quote else "0",
        change=str(quote.change) if quote and quote.change is not None else None,
        change_pct=str(quote.change_pct) if quote and quote.change_pct is not None else None,
        quote_ts=quote.quote_ts if quote else now,
        currency=asset.currency,
        delay_minutes=quote.delay_minutes if quote else 0,
        freshness=f.status,
        market_open=f.market_open,
    ).model_dump()


@router.get("/markets/quotes")
def list_quotes(
    response: Response,
    asset_ids: Optional[str] = Query(None),
    asset_type: Optional[str] = Query(None),
    exchange_id: Optional[str] = Query(None),
    cursor: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    offset = decode_cursor(cursor)
    q = select(Asset).where(Asset.status == "active").order_by(Asset.asset_id)
    if asset_ids:
        q = q.where(Asset.asset_id.in_(asset_ids.split(",")))
    if asset_type:
        q = q.where(Asset.asset_type == asset_type)
    if exchange_id:
        q = q.where(Asset.exchange_id == exchange_id)
    rows = session.scalars(q.offset(offset).limit(limit + 1)).all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    quotes = {mq.asset_id: mq for mq in session.scalars(select(MarketQuote))}
    now = datetime.datetime.now(_UTC)
    set_rate_limit_headers(response)
    return {
        "items": [
            _quote_out(session, a, quotes.get(a.asset_id), now) for a in rows
        ],
        "next_cursor": encode_cursor(offset + limit) if has_more else None,
    }


_VALID_CATEGORIES = {
    "stocks": "stock",
    "etfs": "etf",
    "indices": "index",
    "forex": "forex",
    "crypto": "crypto",
    "commodities": "commodity",
    "bonds": "bond_yield",
}


@router.get("/markets/{category}", response_model=None)
def list_market_category(
    category: str,
    response: Response,
    cursor: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    """§8 Markets tabs: /markets/stocks|etfs|indices|forex|crypto|commodities|bonds."""
    asset_type = _VALID_CATEGORIES.get(category)
    if asset_type is None:
        return err(400, "bad_request", f"unknown category {category!r}")
    offset = decode_cursor(cursor)
    q = (
        select(Asset)
        .where(Asset.status == "active", Asset.asset_type == asset_type)
        .order_by(Asset.asset_id)
    )
    rows = list(session.scalars(q.offset(offset).limit(limit + 1)))
    has_more = len(rows) > limit
    rows = rows[:limit]
    quotes = {mq.asset_id: mq for mq in session.scalars(select(MarketQuote))}
    now = datetime.datetime.now(_UTC)
    set_rate_limit_headers(response)
    return {
        "category": category,
        "items": [_quote_out(session, a, quotes.get(a.asset_id), now) for a in rows],
        "next_cursor": encode_cursor(offset + limit) if has_more else None,
    }
