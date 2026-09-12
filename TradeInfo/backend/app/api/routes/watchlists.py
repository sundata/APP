"""Watchlist endpoints (REQUIREMENTS §10, AC-005): real CRUD, ≤200 items per
list, idempotent add, reorder. All routes require auth."""

import datetime
import uuid
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.asset import Asset
from app.models.market_quote import MarketQuote
from app.models.user import User
from app.models.watchlist import Watchlist, WatchlistItem
from app.schemas import WatchlistItemOut, WatchlistOut
from app.services.freshness import freshness_for_row

router = APIRouter(tags=["watchlists"])
_UTC = datetime.timezone.utc
MAX_ITEMS_PER_LIST = 200
DEFAULT_LIST_NAME = "我的自选"


class WatchlistIn(BaseModel):
    name: str


class WatchlistPatch(BaseModel):
    name: Optional[str] = None
    position: Optional[int] = None


class WatchlistItemIn(BaseModel):
    asset_id: str


class ReorderIn(BaseModel):
    asset_ids: list[str]


def _user_watchlist(session: Session, user: User, watchlist_id: str) -> Optional[Watchlist]:
    wl = session.get(Watchlist, watchlist_id)
    return wl if wl is not None and wl.user_id == user.id else None


def _ensure_default(session: Session, user: User) -> None:
    has = session.scalars(
        select(Watchlist).where(Watchlist.user_id == user.id).limit(1)
    ).first()
    if has is None:
        session.add(
            Watchlist(id=uuid.uuid4().hex, user_id=user.id, name=DEFAULT_LIST_NAME)
        )
        session.flush()


def _items_payload(session: Session, wl: Watchlist) -> dict[str, Any]:
    now = datetime.datetime.now(_UTC)
    items = session.scalars(
        select(WatchlistItem)
        .where(WatchlistItem.watchlist_id == wl.id)
        .order_by(WatchlistItem.position, WatchlistItem.added_at)
    ).all()
    out = []
    for it in items:
        asset = session.get(Asset, it.asset_id)
        if asset is None:
            continue
        quote = session.get(MarketQuote, it.asset_id)
        f = freshness_for_row(session, asset, quote, now)
        out.append(
            WatchlistItemOut(
                asset_id=it.asset_id,
                symbol=asset.symbol,
                name=asset.name,
                latest_price=str(quote.price) if quote else None,
                change_pct=(
                    str(quote.change_pct)
                    if quote and quote.change_pct is not None
                    else None
                ),
                freshness=f.status,
                added_at=it.added_at,
            ).model_dump()
        )
    return {"watchlist_id": wl.id, "items": out}


@router.get("/watchlists", response_model=None)
def list_watchlists(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    _ensure_default(session, user)
    rows = session.scalars(
        select(Watchlist)
        .where(Watchlist.user_id == user.id)
        .order_by(Watchlist.position, Watchlist.created_at)
    ).all()
    counts = {
        wid: cnt
        for wid, cnt in session.execute(
            select(WatchlistItem.watchlist_id, func.count()).group_by(
                WatchlistItem.watchlist_id
            )
        )
    }
    set_rate_limit_headers(response)
    return {
        "items": [
            WatchlistOut(
                id=w.id, name=w.name, item_count=counts.get(w.id, 0)
            ).model_dump()
            for w in rows
        ]
    }


@router.post("/watchlists", status_code=201, response_model=None)
def create_watchlist(
    body: WatchlistIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    name = body.name.strip()
    if not name:
        return err(400, "bad_request", "name required")
    wl = Watchlist(id=uuid.uuid4().hex, user_id=user.id, name=name[:100])
    session.add(wl)
    session.flush()
    set_rate_limit_headers(response)
    return WatchlistOut(id=wl.id, name=wl.name, item_count=0).model_dump()


@router.patch("/watchlists/{watchlist_id}", response_model=None)
def update_watchlist(
    watchlist_id: str,
    body: WatchlistPatch,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    if wl is None:
        return err(404, "not_found", "watchlist not found")
    if body.name is not None:
        wl.name = body.name.strip()[:100] or wl.name
    if body.position is not None:
        wl.position = body.position
    cnt = session.scalar(
        select(func.count())
        .select_from(WatchlistItem)
        .where(WatchlistItem.watchlist_id == wl.id)
    ) or 0
    set_rate_limit_headers(response)
    return WatchlistOut(id=wl.id, name=wl.name, item_count=cnt).model_dump()


@router.delete("/watchlists/{watchlist_id}", status_code=204, response_model=None)
def delete_watchlist(
    watchlist_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[None, JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    if wl is None:
        return err(404, "not_found", "watchlist not found")
    for it in session.scalars(
        select(WatchlistItem).where(WatchlistItem.watchlist_id == wl.id)
    ):
        session.delete(it)
    session.delete(wl)
    return None


@router.get("/watchlists/{watchlist_id}/items", response_model=None)
def list_watchlist_items(
    watchlist_id: str,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    if wl is None:
        return err(404, "not_found", "watchlist not found")
    set_rate_limit_headers(response)
    return _items_payload(session, wl)


@router.post("/watchlists/{watchlist_id}/items", status_code=201, response_model=None)
def add_watchlist_item(
    watchlist_id: str,
    body: WatchlistItemIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    if wl is None:
        return err(404, "not_found", "watchlist not found")
    if session.get(Asset, body.asset_id) is None:
        return err(404, "not_found", f"asset {body.asset_id} not found")
    count = session.scalar(
        select(func.count())
        .select_from(WatchlistItem)
        .where(WatchlistItem.watchlist_id == wl.id)
    ) or 0
    if session.get(WatchlistItem, (wl.id, body.asset_id)) is None:
        if count >= MAX_ITEMS_PER_LIST:
            return err(409, "limit_exceeded", "watchlist is full (200)")
        session.add(
            WatchlistItem(
                watchlist_id=wl.id, asset_id=body.asset_id, position=count
            )
        )
    set_rate_limit_headers(response)
    return _items_payload(session, wl)


@router.delete(
    "/watchlists/{watchlist_id}/items/{asset_id}",
    status_code=204,
    response_model=None,
)
def remove_watchlist_item(
    watchlist_id: str,
    asset_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[None, JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    item = (
        session.get(WatchlistItem, (wl.id, asset_id)) if wl is not None else None
    )
    if item is None:
        return err(404, "not_found", "item not found")
    session.delete(item)
    return None


@router.patch("/watchlists/{watchlist_id}/items/reorder", response_model=None)
def reorder_items(
    watchlist_id: str,
    body: ReorderIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    wl = _user_watchlist(session, user, watchlist_id)
    if wl is None:
        return err(404, "not_found", "watchlist not found")
    for pos, asset_id in enumerate(body.asset_ids):
        item = session.get(WatchlistItem, (wl.id, asset_id))
        if item is not None:
            item.position = pos
    set_rate_limit_headers(response)
    return _items_payload(session, wl)
