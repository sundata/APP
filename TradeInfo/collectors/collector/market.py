"""MarketCollector (REQUIREMENTS §19).

Pipeline per run (§16.1, §36):
    collect raw -> RawStore archive -> normalize -> full validation
    -> valid: upsert market_quotes (+ optional Redis fan-out)
    -> invalid: quote_quarantine row (never served)

The seeded `mock_market` source is an internal random-walk generator so the
whole pipeline is exercisable before any licensed vendor is enabled (§17).
For exchange-bound assets it emits ticks at last_close when the market is
closed — mirroring how real feeds hold the last close.
"""

import datetime
import random
from typing import Any, Iterable, Optional, Protocol
from zoneinfo import ZoneInfo

from app.models.asset import Asset
from app.models.data_source import DataSource
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.models.market_quote import MarketQuote
from app.models.quarantine import QuoteQuarantine
from app.seed.base_prices import BASE_PRICES as _BASE_PRICES
from app.services.alert_engine import check_quotes
from app.services.market_hours import is_market_open, last_close_utc
from sqlalchemy import select
from sqlalchemy.orm import Session

from collector.base import BaseCollector, _now
from collector.normalize import NormalizeError, normalize_quote
from collector.raw_store import RawStore
from collector.tick_sink import TickSink
from collector.validate import QuoteValidationError, validate_quote


class RedisLike(Protocol):
    def hset(self, name: str, mapping: dict[str, str]) -> Any: ...


def _calendar_map(
    session: Session,
) -> dict[tuple[str, datetime.date], MarketCalendar]:
    return {
        (r.exchange_id, r.date): r
        for r in session.scalars(select(MarketCalendar)).all()
    }


class MockMarketCollector(BaseCollector):
    """Random-walk quote generator for `internal` sources."""

    collector_type = "MarketCollector"

    def __init__(
        self,
        session: Session,
        raw_store: Optional[RawStore] = None,
        redis: Optional[RedisLike] = None,
        rng: Optional[random.Random] = None,
        tick_sink: Optional["TickSink"] = None,
    ) -> None:
        super().__init__()
        self.session = session
        self.raw_store = raw_store or RawStore()
        self.redis = redis
        self._rng = rng or random.Random()
        self.tick_sink = tick_sink

    def collect(self, source: DataSource) -> Iterable[dict[str, Any]]:
        assets = self.session.scalars(
            select(Asset).where(Asset.status == "active")
        ).all()
        exchanges = {
            e.exchange_id: e for e in self.session.scalars(select(Exchange))
        }
        cals = _calendar_map(self.session)
        now = _now()
        for a in assets:
            ts = now
            exch = exchanges.get(a.exchange_id) if a.exchange_id else None
            if exch is not None:
                local_day = now.astimezone(ZoneInfo(exch.timezone)).date()
                cal = cals.get((exch.exchange_id, local_day))
                if not is_market_open(exch, now, cal):
                    # closed market -> hold last close, like a real feed
                    exch_cals = {
                        d: c for (eid, d), c in cals.items() if eid == exch.exchange_id
                    }
                    ts = last_close_utc(exch, now, exch_cals) or now
            base = _BASE_PRICES.get(a.asset_id, 100.0)
            drift = self._rng.uniform(-0.01, 0.01)
            price = base * (1 + drift)
            yield {
                "asset_id": a.asset_id,
                "symbol": a.symbol,
                "price": round(price, 6),
                "change": round(price - base, 6),
                "change_pct": round(drift * 100, 4),
                "day_high": round(price * 1.005, 6),
                "day_low": round(price * 0.995, 6),
                "volume": self._rng.randint(10_000, 5_000_000),
                "ts": ts.isoformat(),
                "currency": a.currency,
            }

    def handle_items(
        self,
        session: Session,
        source: DataSource,
        items: list[dict[str, Any]],
    ) -> None:
        self.raw_store.write(
            "market", source.source_id, items, source_url=source.base_url
        )
        assets = {a.asset_id: a for a in session.scalars(select(Asset))}
        exchanges = {
            e.exchange_id: e for e in session.scalars(select(Exchange))
        }
        cals = _calendar_map(session)
        last: dict[str, dict[str, Any]] = {
            q.asset_id: {"price": q.price, "quote_ts": q.quote_ts}
            for q in session.scalars(select(MarketQuote))
        }
        now = _now()
        accepted: list[dict[str, Any]] = []
        for raw in items:
            try:
                quote = normalize_quote(
                    raw, source.source_id, source.delay_minutes
                )
            except NormalizeError as e:
                self._quarantine(session, source, raw, f"normalize_error: {e}")
                continue

            market_open: Optional[bool] = None
            last_close: Optional[datetime.datetime] = None
            asset = assets.get(quote["asset_id"])
            exch = (
                exchanges.get(asset.exchange_id)
                if asset is not None and asset.exchange_id
                else None
            )
            if exch is not None:
                local_day = quote["quote_ts"].astimezone(
                    ZoneInfo(exch.timezone)
                ).date()
                cal = cals.get((exch.exchange_id, local_day))
                market_open = is_market_open(exch, quote["quote_ts"], cal)
                exch_cals = {
                    d: c for (eid, d), c in cals.items() if eid == exch.exchange_id
                }
                last_close = last_close_utc(exch, quote["quote_ts"], exch_cals)

            try:
                validate_quote(
                    quote,
                    assets,
                    now,
                    last=last.get(quote["asset_id"]),
                    market_open=market_open,
                    last_close=last_close,
                )
            except QuoteValidationError as e:
                self._quarantine(session, source, raw, str(e), quote["quote_ts"])
                continue

            self._upsert(session, quote)
            accepted.append(quote)
            last[quote["asset_id"]] = {
                "price": quote["price"],
                "quote_ts": quote["quote_ts"],
            }
        if self.tick_sink is not None and accepted:
            self.tick_sink.write(accepted)  # raw ticks -> BigQuery/JSONL
        if accepted:
            check_quotes(session, accepted, now)  # alert engine (§30)

    def _quarantine(
        self,
        session: Session,
        source: DataSource,
        raw: dict[str, Any],
        reason: str,
        quote_ts: Optional[datetime.datetime] = None,
    ) -> None:
        session.add(
            QuoteQuarantine(
                asset_id=raw.get("asset_id"),
                source_id=source.source_id,
                reason=reason[:200],
                payload=raw,
                quote_ts=quote_ts,
            )
        )

    def _upsert(self, session: Session, q: dict[str, Any]) -> None:
        session.merge(
            MarketQuote(
                asset_id=q["asset_id"],
                price=q["price"],
                change=q["change"],
                change_pct=q["change_pct"],
                day_high=q["day_high"],
                day_low=q["day_low"],
                volume=q["volume"],
                quote_ts=q["quote_ts"],
                source_id=q["source_id"],
                delay_minutes=q["delay_minutes"],
                updated_at=_now(),
            )
        )
        if self.redis is not None:
            self.redis.hset(
                f"quote:{q['asset_id']}",
                mapping={
                    "price": str(q["price"]),
                    "change": str(q["change"]),
                    "change_pct": str(q["change_pct"]),
                    "quote_ts": q["quote_ts"].isoformat(),
                    "delay_minutes": str(q["delay_minutes"]),
                    "source_id": q["source_id"],
                },
            )

