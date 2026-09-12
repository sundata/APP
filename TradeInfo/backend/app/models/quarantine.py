import datetime
from typing import Any, Optional

from sqlalchemy import JSON, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class QuoteQuarantine(Base):
    """Rejected quote payloads (REQUIREMENTS §36). Never served to clients;
    kept for audit/debug/reprocessing."""

    __tablename__ = "quote_quarantine"
    __table_args__ = (Index("ix_quote_quarantine_source", "source_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    asset_id: Mapped[Optional[str]] = mapped_column(
        Text, nullable=True
    )  # no FK — "unknown asset" is a common quarantine reason
    source_id: Mapped[str] = mapped_column(
        Text, ForeignKey("data_sources.source_id"), nullable=False
    )
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    quote_ts: Mapped[Optional[datetime.datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
