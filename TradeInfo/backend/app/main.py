from fastapi import FastAPI

from app.api.errors import install_error_handlers
from app.api.routes import (
    admin,
    alerts,
    assets,
    auth,
    calendar,
    exchanges,
    health,
    markets,
    news,
    notifications,
    portfolio,
    search,
    watchlists,
    ws,
)


def create_app() -> FastAPI:
    app = FastAPI(title="SimpleMarket API", version="0.1.0")
    install_error_handlers(app)
    admin.install_admin_handlers(app)
    for r in (
        health,
        auth,
        search,
        markets,
        assets,
        news,
        calendar,
        exchanges,
        watchlists,
        alerts,
        admin,
        notifications,
        portfolio,
    ):
        app.include_router(r.router, prefix="/api/v1")
    app.include_router(ws.router)  # /ws/quotes — no /api prefix (§25)
    return app


app = create_app()
