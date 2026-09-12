"""Auth endpoints (REQUIREMENTS §26): register / login / refresh / logout /
OAuth (google|apple via injectable verifier) / me."""

import uuid
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.user import User
from app.services.auth import (
    AuthError,
    hash_password,
    issue_tokens,
    oauth_login,
    revoke_refresh,
    rotate_refresh,
    user_out,
    verify_password,
)

router = APIRouter(tags=["auth"])


class RegisterIn(BaseModel):
    email: str
    password: str = Field(min_length=8)
    display_name: Optional[str] = None
    locale: str = "en"


class LoginIn(BaseModel):
    email: str
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class OAuthIn(BaseModel):
    provider: str
    id_token: str
    display_name: Optional[str] = None


@router.post("/auth/register", status_code=201, response_model=None)
def register(
    body: RegisterIn,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    email = body.email.strip().lower()
    if "@" not in email:
        return err(400, "bad_request", "invalid email")
    exists = session.scalars(select(User).where(User.email == email)).first()
    if exists is not None:
        return err(409, "conflict", "email already registered")
    user = User(
        id=uuid.uuid4().hex,
        email=email,
        password_hash=hash_password(body.password),
        display_name=body.display_name,
        locale=body.locale,
        provider="password",
    )
    session.add(user)
    session.flush()
    set_rate_limit_headers(response)
    return issue_tokens(session, user)


@router.post("/auth/login", response_model=None)
def login(
    body: LoginIn,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    user = session.scalars(
        select(User).where(User.email == body.email.strip().lower())
    ).first()
    if user is None or user.password_hash is None:
        return err(401, "invalid_credentials", "bad email or password")
    if not verify_password(body.password, user.password_hash):
        return err(401, "invalid_credentials", "bad email or password")
    set_rate_limit_headers(response)
    return issue_tokens(session, user)


@router.post("/auth/refresh", response_model=None)
def refresh(
    body: RefreshIn,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    try:
        tokens = rotate_refresh(session, body.refresh_token)
    except AuthError:
        return err(401, "invalid_refresh", "invalid or expired refresh token")
    set_rate_limit_headers(response)
    return tokens


@router.post("/auth/logout", status_code=204, response_model=None)
def logout(
    body: RefreshIn, session: Session = Depends(get_session)
) -> None:
    revoke_refresh(session, body.refresh_token)


@router.post("/auth/oauth", response_model=None)
def oauth(
    body: OAuthIn,
    response: Response,
    session: Session = Depends(get_session),
) -> Union[dict[str, Any], JSONResponse]:
    try:
        from app.services.oauth import configured_verifier

        tokens = oauth_login(
            session, body.provider, body.id_token,
            verifier=configured_verifier(),
        )
    except AuthError as e:
        return err(401, "oauth_failed", str(e))
    set_rate_limit_headers(response)
    return tokens


@router.get("/me", response_model=None)
def me(
    response: Response, user: User = Depends(get_current_user)
) -> dict[str, Any]:
    set_rate_limit_headers(response)
    return {"user": user_out(user)}
