"""Response models matching api/openapi.yaml (the authoritative contract)."""

import datetime
from typing import Any, Optional

from pydantic import BaseModel


class SearchItem(BaseModel):
    asset_id: str
    symbol: str
    name: str
    asset_type: str
    exchange_id: Optional[str] = None
    currency: str


class QuoteOut(BaseModel):
    asset_id: str
    symbol: str
    name: str
    asset_type: str
    price: str
    change: Optional[str] = None
    change_pct: Optional[str] = None
    quote_ts: datetime.datetime
    currency: str
    delay_minutes: int
    freshness: str
    market_open: Optional[bool] = None


class AssetDetailOut(BaseModel):
    asset_id: str
    symbol: str
    name: str
    name_i18n: dict[str, str]
    asset_type: str
    exchange_id: Optional[str] = None
    currency: str
    latest_price: Optional[str] = None
    change_pct: Optional[str] = None
    freshness: str
    is_watchlisted: bool = False


class Candle(BaseModel):
    date: datetime.date
    open: str
    high: str
    low: str
    close: str
    volume: Optional[str] = None


class NewsOut(BaseModel):
    id: str
    title: str
    summary: Optional[str] = None
    source: str
    source_url: str
    published_at: datetime.datetime
    language: str
    importance_score: int
    dedup_count: int
    related_assets: list[str] = []


class CalendarEventOut(BaseModel):
    id: int
    country: str
    currency: str
    event_name: str
    event_time_utc: datetime.datetime
    importance: str
    actual: Optional[str] = None
    forecast: Optional[str] = None
    previous: Optional[str] = None


class ExchangeOut(BaseModel):
    exchange_id: str
    name: str
    country: Optional[str] = None
    timezone: str
    currency: str
    market_open: bool


class WatchlistOut(BaseModel):
    id: str
    name: str
    item_count: int


class WatchlistItemOut(BaseModel):
    asset_id: str
    symbol: str
    name: str
    latest_price: Optional[str] = None
    change_pct: Optional[str] = None
    freshness: str
    added_at: datetime.datetime


class AlertOut(BaseModel):
    id: str
    asset_id: str
    symbol: Optional[str] = None
    direction: str
    price: str
    channel: str
    enabled: bool
    last_triggered_at: Optional[datetime.datetime] = None


class AlertCreateIn(BaseModel):
    asset_id: str
    direction: str
    price: str
    channel: str = "push"


class AlertUpdateIn(BaseModel):
    direction: Optional[str] = None
    price: Optional[str] = None
    channel: Optional[str] = None
    enabled: Optional[bool] = None


class HoldingOut(BaseModel):
    id: str
    asset_id: str
    symbol: Optional[str] = None
    quantity: str
    cost_price: str
    currency: str
    note: Optional[str] = None


class HoldingCreateIn(BaseModel):
    asset_id: str
    quantity: str
    cost_price: str
    note: Optional[str] = None


class Page(BaseModel):
    items: list[Any]
    next_cursor: Optional[str] = None
