"""Notification service (REQUIREMENTS §46, T37-T39).

In-app inbox is the durable layer (notifications table, written by the alert
engine). Push fan-out is a pluggable sender: default NoopSender logs intent —
FCM/APNs/WebPush senders wire in at deploy time and read notify_prefs
(user.settings["notify"]) before sending.
"""

import logging
from typing import Any, Callable, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.alert import Notification
from app.models.user import User

logger = logging.getLogger(__name__)

PushSender = Callable[[str, str, Optional[str], dict[str, Any]], None]


def noop_sender(user_id: str, title: str, body: Optional[str], data: dict[str, Any]) -> None:
    logger.info("push(no-op) user=%s title=%s", user_id, title)


def notify_prefs(user: User) -> dict[str, Any]:
    """User notification preferences; defaults: all on."""
    prefs = (user.settings or {}).get("notify", {})
    return {
        "push": prefs.get("push", True),
        "email": prefs.get("email", False),
        "alert": prefs.get("alert", True),
        "system": prefs.get("system", True),
    }


def fanout(
    session: Session,
    notification: Notification,
    sender: PushSender = noop_sender,
) -> None:
    """Push a stored notification to all of the user's registered devices,
    if prefs allow the channel/type. `sender` receives (user_id, title, body,
    data); platform dispatch happens inside the composite sender."""
    user = session.get(User, notification.user_id)
    if user is None:
        return
    prefs = notify_prefs(user)
    if not prefs.get(notification.type, True) or not prefs.get("push", True):
        return
    sender(user.id, notification.title, notification.body, notification.data or {})


def composite_sender(session: Session) -> PushSender:
    """Dispatch to every PushSubscription of the user via the platform sender.
    Real FCM/APNs/WebPush senders are configured at deploy; without config the
    per-platform send is a no-op (logged)."""
    from app.models.push import PushSubscription

    def send(user_id: str, title: str, body: Optional[str], data: dict[str, Any]) -> None:
        subs = session.scalars(
            select(PushSubscription).where(PushSubscription.user_id == user_id)
        ).all()
        for sub in subs:
            sender_fn = _PLATFORM_SENDERS.get(sub.platform, _noop_platform)
            try:
                sender_fn(sub, title, body or "", data)
            except Exception as e:  # noqa: BLE001 — never break fanout on one device
                logger.warning("push failed platform=%s: %s", sub.platform, e)

    return send


def _noop_platform(sub: Any, title: str, body: str, data: dict[str, Any]) -> None:
    logger.info("push(no-op platform=%s) %s", sub.platform, title)


# deploy wiring: app/services/push.py senders get attached here by factory
_PLATFORM_SENDERS: dict[str, Any] = {}


def register_platform_sender(platform: str, sender: Any) -> None:
    """Attach a real sender (FcmSender/ApnsSender/WebPushSender-like object
    with .send(token_or_endpoint, title, body, data))."""
    _PLATFORM_SENDERS[platform] = lambda sub, t, b, d: sender.send(
        sub.token, t, b, d
    )


def fanout_pending(
    session: Session, sender: PushSender = noop_sender, limit: int = 100
) -> int:
    """Send unsent notifications (called by a worker at deploy time; the
    `data` JSON gains `pushed_at` after send)."""
    import datetime

    rows = session.scalars(
        select(Notification)
        .where(Notification.data["pushed_at"].is_(None))
        .order_by(Notification.created_at)
        .limit(limit)
    ).all()
    sent = 0
    for n in rows:
        fanout(session, n, sender)
        data = dict(n.data or {})
        data["pushed_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        n.data = data
        sent += 1
    return sent
