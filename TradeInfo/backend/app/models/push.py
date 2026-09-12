import datetime
from typing import Any, Optional

from sqlalchemy import JSON, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class PushSubscription(Base):
    """Registered device tokens per platform (REQUIREMENTS §46/T37/T39)."""

    __tablename__ = "push_subscriptions"
    __table_args__ = (Index("ix_push_subs_user", "user_id"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(
        Text, ForeignKey("users.id"), nullable=False
    )
    platform: Mapped[str] = mapped_column(Text, nullable=False)  # fcm|apns|webpush
    token: Mapped[str] = mapped_column(Text, nullable=False)  # device token / endpoint
    # webpush: {"p256dh": ..., "auth": ...}
    keys: Mapped[Optional[dict[str, Any]]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
