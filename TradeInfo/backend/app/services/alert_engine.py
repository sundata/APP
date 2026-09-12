"""Alert Engine (REQUIREMENTS §30, MVP_TASKS T21).

For each accepted quote tick, find enabled price_alerts on that asset whose
threshold is crossed and whose cooldown has elapsed -> write alert_trigger_log,
update last_triggered_at, enqueue an in-app notification (push fan-out reads
the queue at deploy time, T37).
"""

import datetime
from decimal import Decimal
from typing import Any, Iterable, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.alert import AlertTriggerLog, Notification, PriceAlert

UTC = datetime.timezone.utc
ALERT_COOLDOWN = datetime.timedelta(hours=1)


def check_quotes(
    session: Session,
    quotes: Iterable[dict[str, Any]],
    now: Optional[datetime.datetime] = None,
) -> int:
    """Evaluate alerts against a batch of canonical quotes. Returns trigger count."""
    now = now or datetime.datetime.now(UTC)
    quotes = list(quotes)
    if not quotes:
        return 0
    asset_ids = {q["asset_id"] for q in quotes}
    alerts = session.scalars(
        select(PriceAlert).where(
            PriceAlert.asset_id.in_(asset_ids),
            PriceAlert.enabled.is_(True),
        )
    ).all()
    by_asset: dict[str, list[PriceAlert]] = {}
    for a in alerts:
        by_asset.setdefault(a.asset_id, []).append(a)

    triggered = 0
    for q in quotes:
        price: Decimal = q["price"]
        quote_ts = q["quote_ts"]
        if quote_ts.tzinfo is None:
            quote_ts = quote_ts.replace(tzinfo=UTC)
        for alert in by_asset.get(q["asset_id"], []):
            last = alert.last_triggered_at
            if last is not None and last.tzinfo is None:
                last = last.replace(tzinfo=UTC)
            if last is not None and now - last < ALERT_COOLDOWN:
                continue
            hit = (
                price >= alert.price
                if alert.direction == "above"
                else price <= alert.price
            )
            if not hit:
                continue
            alert.last_triggered_at = now
            session.add(
                AlertTriggerLog(
                    alert_id=alert.id,
                    triggered_price=price,
                    quote_ts=quote_ts,
                )
            )
            session.add(
                Notification(
                    user_id=alert.user_id,
                    type="alert",
                    title=f"{q['asset_id']} {alert.direction} {alert.price}",
                    body=f"现价 {price}（{quote_ts.isoformat()}）",
                    data={
                        "alert_id": alert.id,
                        "asset_id": q["asset_id"],
                        "price": str(price),
                        "direction": alert.direction,
                    },
                )
            )
            triggered += 1
    return triggered
