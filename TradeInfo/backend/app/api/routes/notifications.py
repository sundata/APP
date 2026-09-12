"""In-app notification center + notify prefs (REQUIREMENTS §46, T38)."""

import datetime
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.alert import Notification
from app.models.user import User
from app.services.notifications import notify_prefs

router = APIRouter(tags=["notifications"])
_UTC = datetime.timezone.utc


class DeviceIn(BaseModel):
    platform: str  # fcm | apns | webpush
    token: str
    keys: Optional[dict[str, Any]] = None


class PrefsIn(BaseModel):
    push: Optional[bool] = None
    email: Optional[bool] = None
    alert: Optional[bool] = None
    system: Optional[bool] = None


def _notif_out(n: Notification) -> dict[str, Any]:
    return {
        "id": n.id,
        "type": n.type,
        "title": n.title,
        "body": n.body,
        "data": n.data or {},
        "read": n.read_at is not None,
        "created_at": n.created_at.isoformat(),
    }


@router.get("/notifications", response_model=None)
def list_notifications(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    rows = session.scalars(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
    ).all()
    unread = session.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
    ) or 0
    set_rate_limit_headers(response)
    return {"items": [_notif_out(n) for n in rows], "unread": unread}


@router.post("/notifications/{notif_id}/read", response_model=None)
def mark_read(
    notif_id: int,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    n = session.get(Notification, notif_id)
    if n is None or n.user_id != user.id:
        return err(404, "not_found", "notification not found")
    if n.read_at is None:
        n.read_at = datetime.datetime.now(_UTC)
    set_rate_limit_headers(response)
    return _notif_out(n)


@router.post("/notifications/read-all", response_model=None)
def mark_all_read(
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    now = datetime.datetime.now(_UTC)
    for n in session.scalars(
        select(Notification).where(
            Notification.user_id == user.id, Notification.read_at.is_(None)
        )
    ):
        n.read_at = now
    set_rate_limit_headers(response)
    return {"ok": True}


@router.post("/notifications/devices", status_code=201, response_model=None)
def register_device(
    body: DeviceIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    """Register a push device token (FCM/APNs token or webpush endpoint)."""
    from app.models.push import PushSubscription

    if body.platform not in ("fcm", "apns", "webpush"):
        return err(400, "bad_request", "platform must be fcm|apns|webpush")
    existing = session.scalars(
        select(PushSubscription).where(PushSubscription.token == body.token)
    ).first()
    if existing is not None and existing.user_id == user.id:
        sub = existing
        sub.platform = body.platform
        sub.keys = body.keys
    else:
        sub = PushSubscription(
            user_id=user.id, platform=body.platform,
            token=body.token, keys=body.keys,
        )
        session.add(sub)
        session.flush()
    set_rate_limit_headers(response)
    return {"id": sub.id, "platform": sub.platform}


@router.delete("/notifications/devices/{token}", status_code=204, response_model=None)
def unregister_device(
    token: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Union[None, JSONResponse]:
    from app.models.push import PushSubscription

    sub = session.scalars(
        select(PushSubscription).where(
            PushSubscription.token == token,
            PushSubscription.user_id == user.id,
        )
    ).first()
    if sub is None:
        return err(404, "not_found", "device not found")
    session.delete(sub)
    return None


@router.get("/notifications/prefs", response_model=None)
def get_prefs(
    response: Response, user: User = Depends(get_current_user)
) -> dict[str, Any]:
    set_rate_limit_headers(response)
    return notify_prefs(user)


@router.put("/notifications/prefs", response_model=None)
def put_prefs(
    body: PrefsIn,
    response: Response,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    prefs = notify_prefs(user)
    for k in ("push", "email", "alert", "system"):
        v = getattr(body, k)
        if v is not None:
            prefs[k] = v
    settings = dict(user.settings or {})
    settings["notify"] = prefs
    user.settings = settings
    set_rate_limit_headers(response)
    return prefs
