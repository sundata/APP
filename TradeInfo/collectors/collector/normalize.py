"""Normalize raw source payloads into the canonical quote shape (§16.1).

Canonical quote dict:
    asset_id, symbol, price, change, change_pct, day_high, day_low, volume,
    quote_ts (aware datetime), currency, source_id, delay_minutes
"""

import datetime
from decimal import Decimal, InvalidOperation
from typing import Any, Optional

_UTC = datetime.timezone.utc


class NormalizeError(ValueError):
    pass


def _dec(value: Any, field: str) -> Optional[Decimal]:
    if value is None:
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as e:
        raise NormalizeError(f"{field} not numeric: {value!r}") from e


def _ts(value: Any) -> datetime.datetime:
    if isinstance(value, datetime.datetime):
        ts = value
    elif isinstance(value, (int, float)):
        ts = datetime.datetime.fromtimestamp(value, _UTC)
    elif isinstance(value, str):
        ts = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    else:
        raise NormalizeError(f"bad quote_ts: {value!r}")
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=_UTC)
    return ts


def normalize_quote(raw: dict[str, Any], source_id: str, delay_minutes: int) -> dict[str, Any]:
    try:
        asset_id = raw["asset_id"]
        symbol = raw["symbol"]
        currency = raw["currency"]
        quote_ts = _ts(raw["ts"])
    except KeyError as e:
        raise NormalizeError(f"missing field {e}") from e

    price = _dec(raw.get("price"), "price")
    if price is None:
        raise NormalizeError("missing price")

    return {
        "asset_id": asset_id,
        "symbol": symbol,
        "price": price,
        "change": _dec(raw.get("change"), "change"),
        "change_pct": _dec(raw.get("change_pct"), "change_pct"),
        "day_high": _dec(raw.get("day_high"), "day_high"),
        "day_low": _dec(raw.get("day_low"), "day_low"),
        "volume": _dec(raw.get("volume"), "volume"),
        "quote_ts": quote_ts,
        "currency": currency,
        "source_id": source_id,
        "delay_minutes": delay_minutes,
    }
