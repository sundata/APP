"""Auth service: HS256 JWT (stdlib, no deps), pbkdf2 passwords, refresh-token
rotation, pluggable OAuth verifier (real Google/Apple verification wires in at
deploy time; tests inject a mock)."""

import base64
import datetime
import hashlib
import hmac
import json
import secrets
import uuid
from typing import Any, Callable, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import RefreshToken, User

UTC = datetime.timezone.utc

ACCESS_TTL = 3600  # 1h
REFRESH_TTL_DAYS = 30
_PBKDF2_ITERATIONS = 120_000


class AuthError(Exception):
    pass


# ---- password ----

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), bytes.fromhex(salt), _PBKDF2_ITERATIONS
    )
    return f"pbkdf2${_PBKDF2_ITERATIONS}${salt}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, iters, salt, hex_digest = stored.split("$")
        digest = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), bytes.fromhex(salt), int(iters)
        )
        return hmac.compare_digest(digest.hex(), hex_digest)
    except (ValueError, AttributeError):
        return False


# ---- JWT (HS256) ----

def _b64e(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _b64d(raw: str) -> bytes:
    return base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4))


def jwt_encode(subject: str, secret: str, ttl_seconds: int = ACCESS_TTL) -> str:
    now = int(datetime.datetime.now(UTC).timestamp())
    header = _b64e(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64e(
        json.dumps({"sub": subject, "iat": now, "exp": now + ttl_seconds}).encode()
    )
    sig = hmac.new(
        secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256
    ).digest()
    return f"{header}.{payload}.{_b64e(sig)}"


def jwt_decode(token: str, secret: str) -> dict[str, Any]:
    try:
        header, payload, sig = token.split(".")
        expected = hmac.new(
            secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256
        ).digest()
        if not hmac.compare_digest(_b64d(sig), expected):
            raise AuthError("bad signature")
        data: dict[str, Any] = json.loads(_b64d(payload))
    except (ValueError, KeyError, json.JSONDecodeError) as e:
        raise AuthError("malformed token") from e
    if data.get("exp", 0) < int(datetime.datetime.now(UTC).timestamp()):
        raise AuthError("token expired")
    return data


# ---- token pairs ----

def _hash_refresh(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def issue_tokens(session: Session, user: User) -> dict[str, Any]:
    access = jwt_encode(user.id, settings.secret_key, ACCESS_TTL)
    refresh = secrets.token_urlsafe(48)
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=_hash_refresh(refresh),
            expires_at=datetime.datetime.now(UTC)
            + datetime.timedelta(days=REFRESH_TTL_DAYS),
        )
    )
    return {
        "access_token": access,
        "token_type": "bearer",
        "expires_in": ACCESS_TTL,
        "refresh_token": refresh,
        "user": user_out(user),
    }


def rotate_refresh(session: Session, token: str) -> dict[str, Any]:
    row = session.scalars(
        select(RefreshToken).where(RefreshToken.token_hash == _hash_refresh(token))
    ).first()
    now = datetime.datetime.now(UTC)
    exp = row.expires_at if row else None
    if exp is not None and exp.tzinfo is None:
        exp = exp.replace(tzinfo=UTC)
    if row is None or row.revoked_at is not None or (exp is not None and exp < now):
        raise AuthError("invalid refresh token")
    row.revoked_at = now
    user = session.get(User, row.user_id)
    if user is None:
        raise AuthError("invalid refresh token")
    return issue_tokens(session, user)


def revoke_refresh(session: Session, token: str) -> None:
    row = session.scalars(
        select(RefreshToken).where(RefreshToken.token_hash == _hash_refresh(token))
    ).first()
    if row is not None and row.revoked_at is None:
        row.revoked_at = datetime.datetime.now(UTC)


def user_out(user: User) -> dict[str, Any]:
    return {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "locale": user.locale,
        "provider": user.provider,
        "settings": user.settings or {},
    }


# ---- OAuth verifier (pluggable) ----

OAuthVerifier = Callable[[str, str], dict[str, Any]]


def mock_oauth_verifier(provider: str, id_token: str) -> dict[str, Any]:
    """Dev/test verifier: trusts the token payload. NEVER enable in prod —
    real impls verify Google/Apple signatures + aud (deploy-time wiring)."""
    try:
        _, payload, _ = id_token.split(".")
        claims = json.loads(_b64d(payload))
    except (ValueError, json.JSONDecodeError) as e:
        raise AuthError("bad id_token") from e
    return {"sub": str(claims.get("sub", "")), "email": claims.get("email", "")}


def oauth_login(
    session: Session,
    provider: str,
    id_token: str,
    verifier: Optional[OAuthVerifier] = None,
) -> dict[str, Any]:
    if provider not in ("google", "apple"):
        raise AuthError("unsupported provider")
    verify = verifier or mock_oauth_verifier
    claims = verify(provider, id_token)
    sub = claims["sub"]
    email = claims.get("email") or f"{sub}@{provider}.oauth"
    user = session.scalars(
        select(User).where(User.provider == provider, User.provider_sub == sub)
    ).first()
    if user is None:
        user = session.scalars(select(User).where(User.email == email)).first()
    if user is None:
        user = User(
            id=uuid.uuid4().hex,
            email=email,
            display_name=claims.get("name"),
            provider=provider,
            provider_sub=sub,
        )
        session.add(user)
        session.flush()
    return issue_tokens(session, user)
