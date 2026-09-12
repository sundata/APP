"""Admin console endpoints (REQUIREMENTS §46, T42): source/asset/news/user/
alert monitoring + source toggle. All routes require is_admin (RBAC)."""

import datetime
from typing import Any, Optional, Union

from fastapi import APIRouter, Depends, FastAPI, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.alert import PriceAlert
from app.models.asset import Asset
from app.models.collector import CollectorJob
from app.models.data_source import DataSource
from app.models.news import News
from app.models.quarantine import QuoteQuarantine
from app.models.user import User
from app.services.freshness import evaluate_freshness

router = APIRouter(tags=["admin"], prefix="/admin")
_UTC = datetime.timezone.utc


class _Forbidden(Exception):
    pass


def get_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise _Forbidden()
    return user


def install_admin_handlers(app: FastAPI) -> None:
    @app.exception_handler(_Forbidden)
    async def _forbidden(request: Request, exc: Exception) -> JSONResponse:
        return err(403, "forbidden", "admin required")


@router.get("/sources", response_model=None)
def admin_sources(
    response: Response,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> dict[str, Any]:
    rows = session.scalars(select(DataSource).order_by(DataSource.source_id)).all()
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                "source_id": s.source_id,
                "source_name": s.source_name,
                "data_type": s.data_type,
                "collection_type": s.collection_type,
                "enabled": s.enabled,
                "terms_reviewed": s.terms_reviewed,
                "priority": s.priority,
                "last_success_at": s.last_success_at.isoformat()
                if s.last_success_at
                else None,
                "last_error": s.last_error,
            }
            for s in rows
        ]
    }


@router.post("/sources/{source_id}/toggle", response_model=None)
def toggle_source(
    source_id: str,
    response: Response,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> Union[dict[str, Any], JSONResponse]:
    src = session.get(DataSource, source_id)
    if src is None:
        return err(404, "not_found", "source not found")
    # compliance guard: external sources can't be enabled before terms review
    if not src.enabled and not src.terms_reviewed and src.source_id != "mock_market":
        return err(409, "terms_not_reviewed", "terms/licensing review required")
    src.enabled = not src.enabled
    set_rate_limit_headers(response)
    return {"source_id": src.source_id, "enabled": src.enabled}


@router.get("/jobs", response_model=None)
def admin_jobs(
    response: Response,
    status: Optional[str] = None,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> dict[str, Any]:
    q = select(CollectorJob).order_by(CollectorJob.started_at.desc()).limit(50)
    if status:
        q = q.where(CollectorJob.status == status)
    rows = session.scalars(q).all()
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                "id": j.id,
                "source_id": j.source_id,
                "collector_type": j.collector_type,
                "status": j.status,
                "items_count": j.items_count,
                "started_at": j.started_at.isoformat(),
                "finished_at": j.finished_at.isoformat() if j.finished_at else None,
            }
            for j in rows
        ]
    }


@router.get("/quarantine", response_model=None)
def admin_quarantine(
    response: Response,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> dict[str, Any]:
    rows = session.scalars(
        select(QuoteQuarantine)
        .order_by(QuoteQuarantine.created_at.desc())
        .limit(100)
    ).all()
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                "id": q.id,
                "reason": q.reason,
                "source_id": q.source_id,
                "created_at": q.created_at.isoformat(),
            }
            for q in rows
        ]
    }


@router.get("/freshness", response_model=None)
def admin_freshness(
    response: Response,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> dict[str, Any]:
    now = datetime.datetime.now(_UTC)
    set_rate_limit_headers(response)
    return {
        "items": [
            {
                "asset_id": r.asset_id,
                "status": r.status,
                "age_seconds": r.age_seconds,
                "market_open": r.market_open,
                "source_id": r.source_id,
            }
            for r in evaluate_freshness(session, now)
        ]
    }


@router.get("/stats", response_model=None)
def admin_stats(
    response: Response,
    session: Session = Depends(get_session),
    admin: User = Depends(get_admin),
) -> dict[str, Any]:
    def _cnt(model: Any) -> int:
        return session.scalar(select(func.count()).select_from(model)) or 0

    set_rate_limit_headers(response)
    return {
        "users": _cnt(User),
        "assets": _cnt(Asset),
        "news": _cnt(News),
        "alerts": _cnt(PriceAlert),
        "quarantine": _cnt(QuoteQuarantine),
        "collector_jobs": _cnt(CollectorJob),
    }
