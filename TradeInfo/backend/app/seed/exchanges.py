"""MVP exchange master data (REQUIREMENTS §5).

Sessions are local times [["HH:MM","HH:MM"], ...] supporting lunch breaks.
Per-date sessions/holidays live in `market_calendars`, generated later by the
ReferenceCollector from these regular schedules.
"""

from typing import Any

from sqlalchemy.orm import Session

from app.models.exchange import Exchange

_WEEKDAYS = [0, 1, 2, 3, 4]  # Mon..Fri

EXCHANGES: list[dict[str, Any]] = [
    {
        "exchange_id": "NYSE",
        "mic": "XNYS",
        "name": "New York Stock Exchange",
        "country": "US",
        "timezone": "America/New_York",
        "currency": "USD",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "16:00"]],
    },
    {
        "exchange_id": "NASDAQ",
        "mic": "XNAS",
        "name": "NASDAQ",
        "country": "US",
        "timezone": "America/New_York",
        "currency": "USD",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "16:00"]],
    },
    {
        "exchange_id": "AMEX",
        "mic": "XASE",
        "name": "NYSE American",
        "country": "US",
        "timezone": "America/New_York",
        "currency": "USD",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "16:00"]],
    },
    {
        "exchange_id": "TSE",
        "mic": "XTKS",
        "name": "Tokyo Stock Exchange",
        "country": "JP",
        "timezone": "Asia/Tokyo",
        "currency": "JPY",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:00", "11:30"], ["12:30", "15:00"]],
    },
    {
        "exchange_id": "ASX",
        "mic": "XASX",
        "name": "Australian Securities Exchange",
        "country": "AU",
        "timezone": "Australia/Sydney",
        "currency": "AUD",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["10:00", "16:00"]],
    },
    {
        "exchange_id": "HKEX",
        "mic": "XHKG",
        "name": "Hong Kong Exchanges",
        "country": "HK",
        "timezone": "Asia/Hong_Kong",
        "currency": "HKD",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "12:00"], ["13:00", "16:00"]],
    },
    {
        "exchange_id": "SSE",
        "mic": "XSHG",
        "name": "Shanghai Stock Exchange",
        "country": "CN",
        "timezone": "Asia/Shanghai",
        "currency": "CNY",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "11:30"], ["13:00", "15:00"]],
    },
    {
        "exchange_id": "SZSE",
        "mic": "XSHE",
        "name": "Shenzhen Stock Exchange",
        "country": "CN",
        "timezone": "Asia/Shanghai",
        "currency": "CNY",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:30", "11:30"], ["13:00", "15:00"]],
    },
    {
        "exchange_id": "LSE",
        "mic": "XLON",
        "name": "London Stock Exchange",
        "country": "GB",
        "timezone": "Europe/London",
        "currency": "GBP",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["08:00", "16:30"]],
    },
    {
        "exchange_id": "EURONEXT",
        "mic": "XPAR",
        "name": "Euronext",
        "country": "EU",
        "timezone": "Europe/Paris",
        "currency": "EUR",
        "trading_weekdays": _WEEKDAYS,
        "sessions": [["09:00", "17:30"]],
    },
]


def seed_exchanges(session: Session) -> int:
    """Idempotent upsert of the MVP exchange list. Returns row count written."""
    for row in EXCHANGES:
        session.merge(Exchange(**row))
    return len(EXCHANGES)
