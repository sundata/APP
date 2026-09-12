import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import decode_cursor, encode_cursor, get_session, set_rate_limit_headers
from app.models.economic_event import EconomicEvent
from app.schemas import CalendarEventOut

router = APIRouter(tags=["calendar"])
_UTC = datetime.timezone.utc


@router.get("/calendar/events")
def list_calendar_events(
    response: Response,
    date: Optional[datetime.date] = Query(None),
    importance: Optional[str] = Query(None),
    country: Optional[str] = Query(None),
    cursor: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    offset = decode_cursor(cursor)
    q = select(EconomicEvent).order_by(EconomicEvent.event_time_utc)
    if date is not None:
        start = datetime.datetime.combine(date, datetime.time.min, tzinfo=_UTC)
        end = start + datetime.timedelta(days=1)
        q = q.where(
            EconomicEvent.event_time_utc >= start,
            EconomicEvent.event_time_utc < end,
        )
    if importance and importance != "all":
        q = q.where(EconomicEvent.importance == importance)
    if country:
        q = q.where(EconomicEvent.country == country)
    rows = session.scalars(q.offset(offset).limit(limit + 1)).all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    set_rate_limit_headers(response)
    return {
        "items": [
            CalendarEventOut(
                id=e.id,
                country=e.country,
                currency=e.currency,
                event_name=e.event_name,
                event_time_utc=e.event_time_utc,
                importance=e.importance,
                actual=e.actual,
                forecast=e.forecast,
                previous=e.previous,
            ).model_dump()
            for e in rows
        ],
        "next_cursor": encode_cursor(offset + limit) if has_more else None,
    }
