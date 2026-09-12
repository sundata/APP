"""Daily-bar backfill (MVP_TASKS T11).

Generates synthetic OHLCV history via random walk so /assets/{id}/chart has
data before a licensed vendor is onboarded. Real backfill swaps this for a
vendor historical endpoint — same table, same uniqueness.
"""

import datetime
import random
from decimal import Decimal
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.models.price_history import PriceHistory
from app.seed.base_prices import BASE_PRICES


def _is_trading_day(
    asset: Asset,
    exchange: Optional[Exchange],
    day: datetime.date,
    holidays: set[datetime.date],
) -> bool:
    if exchange is None:
        return True  # 24/7 markets: every day
    if day in holidays:
        return False
    return day.weekday() in (exchange.trading_weekdays or [])


def backfill_daily_bars(
    session: Session,
    days: int = 365,
    rng: Optional[random.Random] = None,
    asset_ids: Optional[list[str]] = None,
    end: Optional[datetime.date] = None,
) -> int:
    """Upsert daily bars. Returns rows written."""
    rng = rng or random.Random()
    end = end or datetime.datetime.now(datetime.timezone.utc).date()

    q = select(Asset).where(Asset.status == "active")
    if asset_ids is not None:
        q = q.where(Asset.asset_id.in_(asset_ids))
    assets = session.scalars(q).all()
    exchanges = {e.exchange_id: e for e in session.scalars(select(Exchange))}
    holidays = {
        r.date for r in session.scalars(
            select(MarketCalendar).where(MarketCalendar.is_holiday)
        )
    }

    written = 0
    for a in assets:
        exch = exchanges.get(a.exchange_id) if a.exchange_id else None
        close = Decimal(str(BASE_PRICES.get(a.asset_id, 100.0)))
        # walk backwards: today's close -> earlier opens
        day = end
        remaining = days
        bars: list[PriceHistory] = []
        while remaining > 0:
            if _is_trading_day(a, exch, day, holidays):
                move = Decimal(str(rng.uniform(-0.02, 0.02)))
                open_ = (close / (Decimal(1) + move)).quantize(Decimal("0.000001"))
                hi = max(open_, close) * Decimal("1.004")
                lo = min(open_, close) * Decimal("0.996")
                bars.append(
                    PriceHistory(
                        asset_id=a.asset_id,
                        date=day,
                        open=open_,
                        high=hi.quantize(Decimal("0.000001")),
                        low=lo.quantize(Decimal("0.000001")),
                        close=close.quantize(Decimal("0.000001")),
                        volume=Decimal(rng.randint(100_000, 50_000_000)),
                    )
                )
                close = open_
                remaining -= 1
            day -= datetime.timedelta(days=1)
        for bar in bars:
            session.merge(bar)
            written += 1
    return written
