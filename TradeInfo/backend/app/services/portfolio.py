"""Position computation (REQUIREMENTS §31): replay the transaction ledger.

- quantity: sum(buy) - sum(sell); negative positions rejected at write time
- avg_cost: remaining cost basis / remaining qty — sells consume cost
  proportionally (weighted-average method)
- unrealized_pnl: qty * (latest_price - avg_cost), in the position's own
  currency (no FX conversion in MVP)
"""

import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.market_quote import MarketQuote
from app.models.portfolio import PortfolioTransaction

UTC = datetime.timezone.utc


def compute_positions(
    session: Session, user_id: str
) -> list[dict[str, Any]]:
    txs = session.scalars(
        select(PortfolioTransaction)
        .where(PortfolioTransaction.user_id == user_id)
        .order_by(PortfolioTransaction.transacted_at, PortfolioTransaction.created_at)
    ).all()

    qty: dict[str, Decimal] = {}
    cost: dict[str, Decimal] = {}
    for tx in txs:
        if tx.side == "buy":
            qty[tx.asset_id] = qty.get(tx.asset_id, Decimal(0)) + tx.quantity
            cost[tx.asset_id] = (
                cost.get(tx.asset_id, Decimal(0)) + tx.quantity * tx.price
            )
        else:  # sell
            q = qty.get(tx.asset_id, Decimal(0))
            if q <= 0:
                continue
            avg = cost[tx.asset_id] / q if q else Decimal(0)
            sold = min(tx.quantity, q)
            qty[tx.asset_id] = q - sold
            cost[tx.asset_id] = cost[tx.asset_id] - sold * avg

    positions = []
    for asset_id, q in qty.items():
        if q <= 0:
            continue
        asset = session.get(Asset, asset_id)
        quote = session.get(MarketQuote, asset_id)
        avg_cost = cost[asset_id] / q
        latest = quote.price if quote else None
        market_value = q * latest if latest is not None else None
        pnl = q * (latest - avg_cost) if latest is not None else None
        positions.append(
            {
                "asset_id": asset_id,
                "symbol": asset.symbol if asset else asset_id,
                "name": asset.name if asset else asset_id,
                "quantity": q,
                "avg_cost": avg_cost,
                "currency": asset.currency if asset else "",
                "latest_price": latest,
                "market_value": market_value,
                "unrealized_pnl": pnl,
            }
        )
    return positions


def remaining_quantity(session: Session, user_id: str, asset_id: str) -> Decimal:
    qty = Decimal(0)
    for tx in session.scalars(
        select(PortfolioTransaction).where(
            PortfolioTransaction.user_id == user_id,
            PortfolioTransaction.asset_id == asset_id,
        )
    ):
        qty += tx.quantity if tx.side == "buy" else -tx.quantity
    return qty
