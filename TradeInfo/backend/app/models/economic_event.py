import datetime
from typing import Optional

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class EconomicEvent(Base):
    """Economic calendar event (REQUIREMENTS §14).

    Natural dedup: (country, event_name, event_time_utc) — the same release
    reported by two sources upserts into one row (§35 spirit).
    """

    __tablename__ = "economic_events"
    __table_args__ = (
        UniqueConstraint(
            "country", "event_name", "event_time_utc", name="uq_econ_event"
        ),
        Index("ix_econ_events_time", "event_time_utc"),
        Index("ix_econ_events_importance", "importance", "event_time_utc"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    country: Mapped[str] = mapped_column(Text, nullable=False)
    currency: Mapped[str] = mapped_column(Text, nullable=False)
    event_name: Mapped[str] = mapped_column(Text, nullable=False)
    event_time_utc: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    importance: Mapped[str] = mapped_column(
        Text, nullable=False, server_default="medium"
    )  # high | medium | low
    actual: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    forecast: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    previous: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source_id: Mapped[Optional[str]] = mapped_column(
        Text, ForeignKey("data_sources.source_id"), nullable=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
