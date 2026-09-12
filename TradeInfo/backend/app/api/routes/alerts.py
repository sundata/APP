"""Alert endpoints (REQUIREMENTS §30): real user-scoped CRUD + trigger history."""

import uuid
from decimal import Decimal, InvalidOperation
from typing import Any, Union

from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.alert import AlertTriggerLog, PriceAlert
from app.models.asset import Asset
from app.models.user import User
from app.schemas import AlertCreateIn, AlertOut, AlertUpdateIn

router = APIRouter(tags=["alerts"])


def _alert_out(a: PriceAlert, symbol: str) -> dict[str, Any]:
    return AlertOut(
        id=a.id,
        asset_id=a.asset_id,
        symbol=symbol,
        direction=a.direction,
        price=str(a.price),
        channel=a.channel,
        enabled=a.enabled,
        last_triggered_at=a.last_triggered_at,
    ).model_dump()


@router.get("/alerts", response_model=None)
def list_alerts(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    rows = session.scalars(
        select(PriceAlert)
        .where(PriceAlert.user_id == user.id)
        .order_by(PriceAlert.created_at.desc())
    ).all()
    symbols = {
        a.asset_id: a.symbol
        for a in session.scalars(
            select(Asset).where(Asset.asset_id.in_([r.asset_id for r in rows]))
        )
    } if rows else {}
    set_rate_limit_headers(response)
    return {
        "items": [_alert_out(a, symbols.get(a.asset_id, a.asset_id)) for a in rows]
    }


@router.post("/alerts", status_code=201, response_model=None)
def create_alert(
    body: AlertCreateIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    asset = session.get(Asset, body.asset_id)
    if asset is None:
        return err(404, "not_found", f"asset {body.asset_id} not found")
    if body.direction not in ("above", "below"):
        return err(400, "bad_request", "direction must be above|below")
    if body.channel not in ("push", "email"):
        return err(400, "bad_request", "channel must be push|email")
    try:
        price = Decimal(body.price)
    except InvalidOperation:
        return err(400, "bad_request", "price must be numeric")
    if price <= 0:
        return err(400, "bad_request", "price must be > 0")
    alert = PriceAlert(
        id=uuid.uuid4().hex,
        user_id=user.id,
        asset_id=body.asset_id,
        direction=body.direction,
        price=price,
        channel=body.channel,
        enabled=True,
    )
    session.add(alert)
    session.flush()
    set_rate_limit_headers(response)
    return _alert_out(alert, asset.symbol)


@router.patch("/alerts/{alert_id}", response_model=None)
def update_alert(
    alert_id: str,
    body: AlertUpdateIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    alert = session.get(PriceAlert, alert_id)
    if alert is None or alert.user_id != user.id:
        return err(404, "not_found", "alert not found")
    if body.direction is not None:
        if body.direction not in ("above", "below"):
            return err(400, "bad_request", "direction must be above|below")
        alert.direction = body.direction
    if body.price is not None:
        try:
            p = Decimal(body.price)
        except InvalidOperation:
            return err(400, "bad_request", "price must be numeric")
        if p <= 0:
            return err(400, "bad_request", "price must be > 0")
        alert.price = p
    if body.channel is not None:
        if body.channel not in ("push", "email"):
            return err(400, "bad_request", "channel must be push|email")
        alert.channel = body.channel
    if body.enabled is not None:
        alert.enabled = body.enabled
    symbol = session.get(Asset, alert.asset_id)
    set_rate_limit_headers(response)
    return _alert_out(alert, symbol.symbol if symbol else alert.asset_id)


@router.delete("/alerts/{alert_id}", status_code=204, response_model=None)
def delete_alert(
    alert_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[None, JSONResponse]:
    alert = session.get(PriceAlert, alert_id)
    if alert is None or alert.user_id != user.id:
        return err(404, "not_found", "alert not found")
    session.delete(alert)
    return None


@router.get("/alerts/{alert_id}/history", response_model=None)
def alert_history(
    alert_id: str,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    alert = session.get(PriceAlert, alert_id)
    if alert is None or alert.user_id != user.id:
        return err(404, "not_found", "alert not found")
    rows = session.scalars(
        select(AlertTriggerLog)
        .where(AlertTriggerLog.alert_id == alert_id)
        .order_by(AlertTriggerLog.created_at.desc())
        .limit(50)
    ).all()
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                "triggered_price": str(r.triggered_price),
                "quote_ts": r.quote_ts.isoformat(),
                "created_at": r.created_at.isoformat(),
            }
            for r in rows
        ]
    }
