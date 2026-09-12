"""Realtime quotes over WebSocket (REQUIREMENTS §25, T19).

Protocol (JSON text frames):

  client -> {"type":"subscribe","asset_ids":["crypto_btcusd",...]}
  server -> {"type":"snapshot","ts":"...","quotes":[{...}]}     # on subscribe
  server -> {"type":"delta","ts":"...","quotes":[{...}]}       # only changed
  server -> {"type":"heartbeat","ts":"..."}                    # every HEARTBEAT_SEC
  client -> {"type":"resync"}                                  # after reconnect
  client -> {"type":"unsubscribe","asset_ids":[...]}

Reconnect = new connection + re-subscribe; server is stateless per conn.
Cloud Run note: session affinity + max 60min conn lifetime — clients must
handle reconnect/resync (§25).
"""

import asyncio
import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import dec_str, get_session
from app.models.asset import Asset
from app.models.market_quote import MarketQuote

router = APIRouter()

UTC = datetime.timezone.utc
POLL_SEC = 2.0        # delta poll interval
HEARTBEAT_SEC = 30.0  # §25 heartbeat


def _snapshot(session: Session, asset_ids: set[str]) -> list[dict[str, Any]]:
    if not asset_ids:
        return []
    quotes = {
        q.asset_id: q
        for q in session.scalars(
            select(MarketQuote).where(MarketQuote.asset_id.in_(asset_ids))
        )
    }
    assets = {
        a.asset_id: a
        for a in session.scalars(select(Asset).where(Asset.asset_id.in_(asset_ids)))
    }
    out = []
    for aid in sorted(asset_ids):
        q = quotes.get(aid)
        a = assets.get(aid)
        out.append(
            {
                "asset_id": aid,
                "symbol": a.symbol if a else aid,
                "price": dec_str(q.price) if q else None,
                "change_pct": dec_str(q.change_pct)
                if q and q.change_pct is not None
                else None,
                "quote_ts": q.quote_ts.isoformat() if q else None,
                "delay_minutes": q.delay_minutes if q else 0,
                "source_id": q.source_id if q else None,
            }
        )
    return out


@router.websocket("/ws/quotes")
async def ws_quotes(
    websocket: WebSocket, session: Session = Depends(get_session)
) -> None:
    await websocket.accept()
    subscribed: set[str] = set()
    last_sent: dict[str, tuple[Optional[str], Optional[str]]] = {}
    last_hb = datetime.datetime.now(UTC)

    async def send(payload: dict[str, Any]) -> None:
        await websocket.send_json(payload)

    try:
        while True:
            # drain client messages without blocking the emit loop
            try:
                msg = await asyncio.wait_for(
                    websocket.receive_json(), timeout=POLL_SEC
                )
            except TimeoutError:
                msg = None
            except WebSocketDisconnect:
                break

            now = datetime.datetime.now(UTC)
            mtype = (msg or {}).get("type")

            if mtype == "subscribe":
                subscribed.update(msg.get("asset_ids") or [])
                await send(
                    {
                        "type": "snapshot",
                        "ts": now.isoformat(),
                        "quotes": _snapshot(session, subscribed),
                    }
                )
                last_sent = {
                    q["asset_id"]: (q["price"], q["quote_ts"])
                    for q in _snapshot(session, subscribed)
                }
            elif mtype == "unsubscribe":
                subscribed.difference_update(msg.get("asset_ids") or [])
                for aid in msg.get("asset_ids") or []:
                    last_sent.pop(aid, None)
            elif mtype == "resync":
                await send(
                    {
                        "type": "snapshot",
                        "ts": now.isoformat(),
                        "quotes": _snapshot(session, subscribed),
                    }
                )
            elif mtype == "ping":
                await send({"type": "pong", "ts": now.isoformat()})

            # delta: emit only quotes that changed since last send
            if subscribed and (msg is None or mtype in (None, "ping")):
                current = _snapshot(session, subscribed)
                changed = [
                    q
                    for q in current
                    if last_sent.get(q["asset_id"]) != (q["price"], q["quote_ts"])
                ]
                if changed:
                    await send(
                        {
                            "type": "delta",
                            "ts": now.isoformat(),
                            "quotes": changed,
                        }
                    )
                    last_sent.update(
                        {q["asset_id"]: (q["price"], q["quote_ts"]) for q in changed}
                    )

            if (now - last_hb).total_seconds() >= HEARTBEAT_SEC:
                await send({"type": "heartbeat", "ts": now.isoformat()})
                last_hb = now
    except WebSocketDisconnect:
        return
