import base64
import datetime
from typing import Any, Iterator, Optional

from fastapi import Depends, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import settings
from app.db import SessionLocal
from app.models.user import User
from app.services.auth import AuthError, jwt_decode

UTC = datetime.timezone.utc
_bearer = HTTPBearer(auto_error=False)


def get_session() -> Iterator[Session]:
    """Request-scoped session: commits on success, rolls back on error."""
    with SessionLocal() as s:
        try:
            yield s
            s.commit()
        except Exception:
            s.rollback()
            raise


DbSession = Depends(get_session)


def get_current_user(
    request: Request,
    session: Session = Depends(get_session),
    creds: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> User:
    """401 envelope when missing/invalid/expired bearer token."""
    if creds is None or creds.scheme.lower() != "bearer":
        raise _Unauthorized()
    try:
        payload = jwt_decode(creds.credentials, settings.secret_key)
    except AuthError as e:
        raise _Unauthorized() from e
    user = session.get(User, str(payload.get("sub", "")))
    if user is None:
        raise _Unauthorized()
    return user


class _Unauthorized(Exception):
    pass


def get_optional_user(
    session: Session = Depends(get_session),
    creds: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> Optional[User]:
    """Like get_current_user but returns None instead of 401 — for endpoints
    that personalize when authed but still serve anonymously."""
    if creds is None or creds.scheme.lower() != "bearer":
        return None
    try:
        payload = jwt_decode(creds.credentials, settings.secret_key)
    except AuthError:
        return None
    return session.get(User, str(payload.get("sub", "")))


def encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(f"o:{offset}".encode()).decode()


def decode_cursor(cursor: Optional[str]) -> int:
    if not cursor:
        return 0
    try:
        raw = base64.urlsafe_b64decode(cursor.encode()).decode()
        prefix, _, value = raw.partition(":")
        if prefix != "o":
            return 0
        return int(value)
    except Exception:  # noqa: BLE001 — bad cursor just restarts at 0
        return 0


def dec_str(v: Any) -> Optional[str]:
    """Decimal -> plain string without trailing zeros (65000.00000000 -> 65000)."""
    if v is None:
        return None
    s = f"{v:f}".rstrip("0").rstrip(".")
    return s or "0"


def set_rate_limit_headers(response: Response, remaining: int = 99) -> None:
    response.headers["X-RateLimit-Limit"] = "100"
    response.headers["X-RateLimit-Remaining"] = str(remaining)
