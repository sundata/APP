"""Portfolio endpoints (REQUIREMENTS §31): transaction ledger + computed
positions. Records only — never trading (§1)."""

import datetime
import uuid
from decimal import Decimal, InvalidOperation
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.asset import Asset
from app.models.portfolio import PortfolioTransaction
from app.models.user import User
from app.services.portfolio import compute_positions, remaining_quantity

router = APIRouter(tags=["portfolio"])
_UTC = datetime.timezone.utc


class TransactionIn(BaseModel):
    asset_id: str
    side: str  # buy | sell
    quantity: str
    price: str
    transacted_at: Optional[datetime.datetime] = None
    note: Optional[str] = None


def _tx_out(tx: PortfolioTransaction, symbol: str) -> dict[str, Any]:
    return {
        "id": tx.id,
        "asset_id": tx.asset_id,
        "symbol": symbol,
        "side": tx.side,
        "quantity": str(tx.quantity),
        "price": str(tx.price),
        "transacted_at": tx.transacted_at.isoformat(),
        "note": tx.note,
    }


@router.get("/portfolio/holdings", response_model=None)
def list_holdings(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    positions = compute_positions(session, user.id)
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                **p,
                "quantity": str(p["quantity"]),
                "avg_cost": str(p["avg_cost"]),
                "latest_price": (
                    str(p["latest_price"]) if p["latest_price"] is not None else None
                ),
                "market_value": (
                    str(p["market_value"]) if p["market_value"] is not None else None
                ),
                "unrealized_pnl": (
                    str(p["unrealized_pnl"]) if p["unrealized_pnl"] is not None else None
                ),
            }
            for p in positions
        ]
    }


@router.get("/portfolio/transactions", response_model=None)
def list_transactions(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    txs = session.scalars(
        select(PortfolioTransaction)
        .where(PortfolioTransaction.user_id == user.id)
        .order_by(PortfolioTransaction.transacted_at.desc())
        .limit(200)
    ).all()
    symbols = {
        a.asset_id: a.symbol
        for a in session.scalars(
            select(Asset).where(Asset.asset_id.in_([t.asset_id for t in txs]))
        )
    } if txs else {}
    set_rate_limit_headers(response)
    return {"items": [_tx_out(t, symbols.get(t.asset_id, t.asset_id)) for t in txs]}


@router.post("/portfolio/transactions", status_code=201, response_model=None)
def create_transaction(
    body: TransactionIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    asset = session.get(Asset, body.asset_id)
    if asset is None:
        return err(404, "not_found", f"asset {body.asset_id} not found")
    if body.side not in ("buy", "sell"):
        return err(400, "bad_request", "side must be buy|sell")
    try:
        qty, price = Decimal(body.quantity), Decimal(body.price)
    except InvalidOperation:
        return err(400, "bad_request", "quantity/price must be numeric")
    if qty <= 0 or price <= 0:
        return err(400, "bad_request", "quantity/price must be > 0")
    if body.side == "sell" and qty > remaining_quantity(session, user.id, body.asset_id):
        return err(400, "bad_request", "sell quantity exceeds position")

    tx = PortfolioTransaction(
        id=uuid.uuid4().hex,
        user_id=user.id,
        asset_id=body.asset_id,
        side=body.side,
        quantity=qty,
        price=price,
        transacted_at=body.transacted_at or datetime.datetime.now(_UTC),
        note=body.note,
    )
    session.add(tx)
    session.flush()
    set_rate_limit_headers(response)
    return _tx_out(tx, asset.symbol)
