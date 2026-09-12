import datetime
from typing import Any

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_session, set_rate_limit_headers
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.schemas import ExchangeOut
from app.services.market_hours import is_market_open

router = APIRouter(tags=["exchanges"])
_UTC = datetime.timezone.utc


@router.get("/exchanges")
def list_exchanges(
    response: Response,
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    rows = session.scalars(select(Exchange).order_by(Exchange.exchange_id)).all()
    cals = {
        (r.exchange_id, r.date): r
        for r in session.scalars(select(MarketCalendar)).all()
    }
    now = datetime.datetime.now(_UTC)
    from zoneinfo import ZoneInfo

    set_rate_limit_headers(response)
    return {
        "items": [
            ExchangeOut(
                exchange_id=e.exchange_id,
                name=e.name,
                country=e.country,
                timezone=e.timezone,
                currency=e.currency,
                market_open=is_market_open(
                    e,
                    now,
                    cals.get(
                        (e.exchange_id, now.astimezone(ZoneInfo(e.timezone)).date())
                    ),
                ),
            ).model_dump()
            for e in rows
        ]
    }
