"""Market open/close resolution (REQUIREMENTS §39 dependency).

Resolution order for a given instant:
1. market_calendars row for the exchange-local date (holiday / override times)
2. exchange.trading_weekdays + exchange.sessions (regular schedule, local time)
"""

import datetime
from typing import Mapping, Optional
from zoneinfo import ZoneInfo

from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar

UTC = datetime.timezone.utc


def sessions_utc(
    exchange: Exchange,
    local_date: datetime.date,
    cal: Optional[MarketCalendar] = None,
) -> list[tuple[datetime.datetime, datetime.datetime]]:
    """UTC session windows for an exchange-local date.

    `cal` (market_calendars row for that date, if any) overrides the regular
    schedule: holiday => closed; explicit open/close => special session.
    """
    if cal is not None:
        if cal.is_holiday:
            return []
        if cal.open_utc is not None and cal.close_utc is not None:
            return [(cal.open_utc, cal.close_utc)]
    if local_date.weekday() not in (exchange.trading_weekdays or []):
        return []
    tz = ZoneInfo(exchange.timezone)
    out: list[tuple[datetime.datetime, datetime.datetime]] = []
    for start, end in exchange.sessions:
        sh, sm = (int(p) for p in start.split(":"))
        eh, em = (int(p) for p in end.split(":"))
        o = datetime.datetime(
            local_date.year, local_date.month, local_date.day, sh, sm, tzinfo=tz
        )
        c = datetime.datetime(
            local_date.year, local_date.month, local_date.day, eh, em, tzinfo=tz
        )
        out.append((o.astimezone(UTC), c.astimezone(UTC)))
    return out


def is_market_open(
    exchange: Exchange,
    dt_utc: datetime.datetime,
    cal: Optional[MarketCalendar] = None,
) -> bool:
    local = dt_utc.astimezone(ZoneInfo(exchange.timezone))
    return any(
        o <= dt_utc <= c for o, c in sessions_utc(exchange, local.date(), cal)
    )


def last_close_utc(
    exchange: Exchange,
    dt_utc: datetime.datetime,
    calendars: Mapping[datetime.date, MarketCalendar],
    max_lookback_days: int = 10,
) -> Optional[datetime.datetime]:
    """Most recent session close <= dt_utc (walks back over weekends/holidays)."""
    tz = ZoneInfo(exchange.timezone)
    day = dt_utc.astimezone(tz).date()
    for back in range(max_lookback_days):
        d = day - datetime.timedelta(days=back)
        for _, close in reversed(sessions_utc(exchange, d, calendars.get(d))):
            if close <= dt_utc:
                return close
    return None
