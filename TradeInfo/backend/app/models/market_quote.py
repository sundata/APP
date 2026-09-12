import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class MarketQuote(Base):
    """Latest canonical quote per asset. PG is the persistent copy; the hot
    read path is Redis `quote:{asset_id}` (DATABASE.md §3)."""

    __tablename__ = "market_quotes"

    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), primary_key=True
    )
    price: Mapped[Decimal] = mapped_column(Numeric(20, 8), nullable=False)
    change: Mapped[Optional[Decimal]] = mapped_column(Numeric(20, 8), nullable=True)
    change_pct: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 4), nullable=True)
    day_high: Mapped[Optional[Decimal]] = mapped_column(Numeric(20, 8), nullable=True)
    day_low: Mapped[Optional[Decimal]] = mapped_column(Numeric(20, 8), nullable=True)
    volume: Mapped[Optional[Decimal]] = mapped_column(Numeric(24, 4), nullable=True)
    quote_ts: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    source_id: Mapped[str] = mapped_column(
        Text, ForeignKey("data_sources.source_id"), nullable=False
    )
    delay_minutes: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    updated_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
