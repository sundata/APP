"""Real OAuth id_token verification (REQUIREMENTS §26).

- Google: verifies via the tokeninfo endpoint (no signature crypto needed;
  also checks `aud` against configured client IDs when set).
- Apple: fetches JWKS from appleid.apple.com and verifies the RS256 signature
  locally with `cryptography`, plus iss/aud/exp claims.

Verifier selection: `settings.oauth_mode` = "real" (default when
SIMPLEMARKET_OAUTH_CLIENT_IDS configured / in prod) or "mock" (dev/test).
Mock mode trusts the payload — NEVER for prod.
"""

import base64
import json
from typing import Any, Callable, Optional

import httpx

from app.config import settings
from app.services.auth import AuthError, mock_oauth_verifier

GOOGLE_TOKENINFO = "https://oauth2.googleapis.com/tokeninfo"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"


def _b64d(raw: str) -> bytes:
    return base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4))


def _jwt_parts(token: str) -> tuple[dict[str, Any], dict[str, Any]]:
    try:
        h, p, _ = token.split(".")
        return json.loads(_b64d(h)), json.loads(_b64d(p))
    except (ValueError, json.JSONDecodeError) as e:
        raise AuthError("malformed id_token") from e


def verify_google(id_token: str, client_ids: Optional[set[str]] = None) -> dict[str, Any]:
    """Verify a Google id_token via the tokeninfo endpoint."""
    try:
        r = httpx.get(
            GOOGLE_TOKENINFO, params={"id_token": id_token}, timeout=10.0
        )
    except httpx.HTTPError as e:
        raise AuthError(f"google verify unreachable: {e}") from e
    if r.status_code != 200:
        raise AuthError("google rejected id_token")
    claims = r.json()
    if client_ids and claims.get("aud") not in client_ids:
        raise AuthError("aud mismatch")
    return {
        "sub": claims["sub"],
        "email": claims.get("email"),
        "name": claims.get("name"),
    }


def verify_apple(
    id_token: str,
    client_ids: Optional[set[str]] = None,
    jwks_url: str = APPLE_JWKS_URL,
) -> dict[str, Any]:
    """Verify an Apple id_token signature (RS256) against Apple's JWKS."""
    import datetime

    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding, rsa

    header, claims = _jwt_parts(id_token)
    kid = header.get("kid")
    try:
        keys = httpx.get(jwks_url, timeout=10.0).json()["keys"]
    except (httpx.HTTPError, json.JSONDecodeError, KeyError) as e:
        raise AuthError("apple JWKS fetch failed") from e
    jwk = next((k for k in keys if k.get("kid") == kid), None)
    if jwk is None:
        raise AuthError("unknown kid")
    n = int.from_bytes(_b64d(jwk["n"]), "big")
    exponent = int.from_bytes(_b64d(jwk["e"]), "big")
    pub = rsa.RSAPublicNumbers(exponent, n).public_key()
    signing_input = ".".join(id_token.split(".")[:2]).encode()
    sig = _b64d(id_token.split(".")[2])
    try:
        pub.verify(sig, signing_input, padding.PKCS1v15(), hashes.SHA256())
    except Exception as e:
        raise AuthError("apple signature invalid") from e
    if claims.get("iss") != "https://appleid.apple.com":
        raise AuthError("iss mismatch")
    if claims.get("exp", 0) < int(datetime.datetime.now(datetime.timezone.utc).timestamp()):
        raise AuthError("id_token expired")
    if client_ids and claims.get("aud") not in client_ids:
        raise AuthError("aud mismatch")
    return {"sub": claims["sub"], "email": claims.get("email"), "name": None}


def configured_verifier() -> Callable[[str, str], dict[str, Any]]:
    """Pick verifier by settings: mock only when explicitly enabled or when
    no client IDs configured outside prod. Prod with real client IDs -> real."""
    client_ids = set(
        x for x in settings.oauth_client_ids.split(",") if x.strip()
    ) or None
    if settings.oauth_mode == "mock":
        if settings.environment == "prod":
            raise AuthError("mock oauth verifier not allowed in prod")
        return mock_oauth_verifier

    def verify(provider: str, id_token: str) -> dict[str, Any]:
        if provider == "google":
            return verify_google(id_token, client_ids)
        if provider == "apple":
            return verify_apple(id_token, client_ids)
        raise AuthError("unsupported provider")

    return verify
