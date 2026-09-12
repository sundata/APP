"""data_freshness_monitor (REQUIREMENTS §39).

Computes a display/status label per asset:
  live    — fresh, source is real-time
  delayed — fresh but source is delayed (delay_minutes > 0) -> UI shows "Delayed"
  stale   — market open but last quote older than threshold -> UI shows "Delayed"/stale
  closed  — market closed; age is expected, NOT stale
  no_data — no quote on record

Never report closed-market data as stale, and never call stale data live (§39).
"""

import datetime
from dataclasses import dataclass
from typing import Mapping, Optional
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.data_source import DataSource
from app.models.exchange import Exchange
from app.models.market_calendar import MarketCalendar
from app.models.market_quote import MarketQuote
from app.services.market_hours import is_market_open

UTC = datetime.timezone.utc

STATUS_LIVE = "live"
STATUS_DELAYED = "delayed"
STATUS_STALE = "stale"
STATUS_CLOSED = "closed"
STATUS_NO_DATA = "no_data"

# floor for the open-market freshness threshold; also 3x source refresh_interval
MIN_STALE_SECONDS = 30.0


@dataclass
class FreshnessResult:
    asset_id: str
    status: str
    age_seconds: Optional[float]
    market_open: Optional[bool]  # None for 24/7 markets
    source_id: Optional[str]
    delay_minutes: int


def stale_threshold_seconds(source: Optional[DataSource]) -> float:
    """How old a quote may get during an open market before it is stale."""
    if source is None:
        return 60.0
    return max(3.0 * source.refresh_interval, MIN_STALE_SECONDS)


def freshness_for(
    asset: Asset,
    quote: Optional[MarketQuote],
    source: Optional[DataSource],
    exchange: Optional[Exchange],
    calendars: Mapping[datetime.date, MarketCalendar],
    now: datetime.datetime,
) -> FreshnessResult:
    delay = quote.delay_minutes if quote is not None else (source.delay_minutes if source else 0)
    if quote is None:
        return FreshnessResult(
            asset.asset_id, STATUS_NO_DATA, None, None,
            source.source_id if source else None, delay,
        )

    # SQLite returns naive datetimes for DateTime(tz); treat as UTC
    quote_ts = quote.quote_ts
    if quote_ts.tzinfo is None:
        quote_ts = quote_ts.replace(tzinfo=UTC)
    age = (now - quote_ts).total_seconds()
    threshold = stale_threshold_seconds(source) + delay * 60.0

    market_open: Optional[bool] = None
    if exchange is not None:
        local_day = now.astimezone(ZoneInfo(exchange.timezone)).date()
        cal = calendars.get(local_day)
        market_open = is_market_open(exchange, now, cal)
        if not market_open:
            # closed market: last-close tick is expected to be old — not stale
            return FreshnessResult(
                asset.asset_id, STATUS_CLOSED, age, False,
                quote.source_id, delay,
            )
        status = (
            STATUS_STALE if age > threshold
            else STATUS_DELAYED if delay > 0
            else STATUS_LIVE
        )
        return FreshnessResult(asset.asset_id, status, age, market_open, quote.source_id, delay)

    status = (
        STATUS_STALE if age > threshold
        else STATUS_DELAYED if delay > 0
        else STATUS_LIVE
    )
    return FreshnessResult(asset.asset_id, status, age, market_open, quote.source_id, delay)


def freshness_for_row(
    session: Session,
    asset: Asset,
    quote: Optional[MarketQuote],
    now: datetime.datetime,
) -> FreshnessResult:
    """Single-asset freshness — convenience wrapper for API handlers."""
    source = (
        session.get(DataSource, quote.source_id) if quote is not None else None
    )
    exch = session.get(Exchange, asset.exchange_id) if asset.exchange_id else None
    cals: dict[datetime.date, MarketCalendar] = {}
    if exch is not None:
        cals = {
            r.date: r
            for r in session.scalars(
                select(MarketCalendar).where(
                    MarketCalendar.exchange_id == exch.exchange_id
                )
            )
        }
    return freshness_for(asset, quote, source, exch, cals, now)


def evaluate_freshness(session: Session, now: datetime.datetime) -> list[FreshnessResult]:
    """Freshness report across all active assets — the §39 monitor output."""
    assets = session.scalars(select(Asset).where(Asset.status == "active")).all()
    quotes = {q.asset_id: q for q in session.scalars(select(MarketQuote))}
    exchanges = {e.exchange_id: e for e in session.scalars(select(Exchange))}
    sources = {s.source_id: s for s in session.scalars(select(DataSource))}
    cal_rows = session.scalars(select(MarketCalendar)).all()

    results: list[FreshnessResult] = []
    for a in assets:
        quote = quotes.get(a.asset_id)
        exch = exchanges.get(a.exchange_id) if a.exchange_id else None
        cals: dict[datetime.date, MarketCalendar] = {}
        if exch is not None:
            cals = {
                r.date: r for r in cal_rows if r.exchange_id == exch.exchange_id
            }
        source = sources.get(quote.source_id) if quote else None
        results.append(
            freshness_for(a, quote, source, exch, cals, now)
        )
    return results


def stale_report(results: list[FreshnessResult]) -> list[FreshnessResult]:
    """Monitoring alarm surface (§39/§40): stale or missing data only."""
    return [r for r in results if r.status in (STATUS_STALE, STATUS_NO_DATA)]
