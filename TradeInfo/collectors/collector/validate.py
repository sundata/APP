"""Quote validation gate (REQUIREMENTS §36). Failures are quarantined, never
served (§36 / AC: quarantine, not display).

Raises QuoteValidationError with a stable reason slug:
  unknown_asset       asset_id not in asset master
  non_positive_price  price <= 0
  currency_mismatch   quote currency != asset currency
  future_timestamp    ts beyond allowed clock skew
  stale_tick          ts too old, or ts <= last stored tick (out-of-order)
  duplicate_tick      same asset + same ts + same price as stored
  conflicting_tick    same ts, different price
  impossible_jump     |pct move| vs last quote beyond per-type threshold
  stale_after_close   market closed and tick > grace after last close
"""

import datetime
from decimal import Decimal
from typing import Any, Mapping, Optional

from app.models.asset import Asset

_UTC = datetime.timezone.utc
MAX_FUTURE_SKEW = datetime.timedelta(minutes=5)
MAX_QUOTE_AGE = datetime.timedelta(days=7)
AFTER_CLOSE_GRACE = datetime.timedelta(minutes=60)

# single-tick |pct move| ceiling by asset type
JUMP_THRESHOLDS = {
    "stock": Decimal("0.25"),
    "etf": Decimal("0.25"),
    "index": Decimal("0.15"),
    "forex": Decimal("0.08"),
    "crypto": Decimal("0.30"),
    "commodity": Decimal("0.20"),
    "bond_yield": Decimal("0.15"),
}


class QuoteValidationError(ValueError):
    pass


def validate_quote(
    quote: dict[str, Any],
    assets: Mapping[str, Asset],
    now: datetime.datetime,
    *,
    last: Optional[Mapping[str, Any]] = None,
    market_open: Optional[bool] = None,
    last_close: Optional[datetime.datetime] = None,
) -> None:
    asset = assets.get(quote["asset_id"])
    if asset is None:
        raise QuoteValidationError(f"unknown_asset: {quote['asset_id']!r}")

    price: Decimal = quote["price"]
    ts: datetime.datetime = quote["quote_ts"]

    if price <= 0:
        raise QuoteValidationError(f"non_positive_price: {price}")
    if quote["currency"] != asset.currency:
        raise QuoteValidationError(
            f"currency_mismatch: {quote['currency']!r} != {asset.currency!r}"
        )
    if ts > now + MAX_FUTURE_SKEW:
        raise QuoteValidationError(f"future_timestamp: {ts}")
    if ts < now - MAX_QUOTE_AGE:
        raise QuoteValidationError(f"stale_tick: {ts}")

    if last is not None:
        last_ts: datetime.datetime = last["quote_ts"]
        last_price: Decimal = last["price"]
        if ts < last_ts:
            raise QuoteValidationError(f"stale_tick: {ts} <= {last_ts}")
        if ts == last_ts:
            if price == last_price:
                raise QuoteValidationError("duplicate_tick")
            raise QuoteValidationError("conflicting_tick")
        threshold = JUMP_THRESHOLDS.get(asset.asset_type, Decimal("0.25"))
        if last_price > 0:
            move = abs(price / last_price - Decimal(1))
            if move > threshold:
                raise QuoteValidationError(
                    f"impossible_jump: {move:.4f} > {threshold}"
                )

    if (
        market_open is False
        and last_close is not None
        and ts > last_close + AFTER_CLOSE_GRACE
    ):
        raise QuoteValidationError(f"stale_after_close: {ts} > {last_close}")
