from typing import Any, Optional

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.deps import _Unauthorized


def err(status: int, code: str, message: str, details: Optional[Any] = None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"error": {"code": code, "message": message, "details": details}},
    )


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(_Unauthorized)
    async def _unauth(request: Request, exc: Exception) -> JSONResponse:
        return err(401, "unauthorized", "missing or invalid token")
