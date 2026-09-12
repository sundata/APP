import datetime
from decimal import Decimal
from typing import Any, Optional

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class PriceAlert(Base):
    __tablename__ = "price_alerts"
    __table_args__ = (Index("ix_price_alerts_asset", "asset_id", "enabled"),)

    id: Mapped[str] = mapped_column(Text, primary_key=True)  # uuid
    user_id: Mapped[str] = mapped_column(
        Text, ForeignKey("users.id"), nullable=False
    )
    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), nullable=False
    )
    direction: Mapped[str] = mapped_column(Text, nullable=False)  # above | below
    price: Mapped[Decimal] = mapped_column(Numeric(20, 8), nullable=False)
    channel: Mapped[str] = mapped_column(
        Text, nullable=False, server_default="push"
    )  # push | email
    enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    last_triggered_at: Mapped[Optional[datetime.datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class AlertTriggerLog(Base):
    __tablename__ = "alert_trigger_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    alert_id: Mapped[str] = mapped_column(
        Text, ForeignKey("price_alerts.id"), nullable=False
    )
    triggered_price: Mapped[Decimal] = mapped_column(Numeric(20, 8), nullable=False)
    quote_ts: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Notification(Base):
    """In-app notification center (REQUIREMENTS §46/T38). Push fan-out (FCM/APNs)
    reads pending rows at deploy time."""

    __tablename__ = "notifications"
    __table_args__ = (Index("ix_notifications_user", "user_id", "created_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        Text, ForeignKey("users.id"), nullable=False
    )
    type: Mapped[str] = mapped_column(Text, nullable=False)  # alert | system
    title: Mapped[str] = mapped_column(Text, nullable=False)
    body: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    data: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, server_default="{}")
    read_at: Mapped[Optional[datetime.datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
