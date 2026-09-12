import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class PortfolioTransaction(Base):
    """Buy/sell ledger entries (REQUIREMENTS §31). Positions are recomputed
    from this ledger — single source of truth, in original currency."""

    __tablename__ = "portfolio_transactions"
    __table_args__ = (Index("ix_portfolio_tx_user", "user_id", "transacted_at"),)

    id: Mapped[str] = mapped_column(Text, primary_key=True)  # uuid
    user_id: Mapped[str] = mapped_column(
        Text, ForeignKey("users.id"), nullable=False
    )
    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), nullable=False
    )
    side: Mapped[str] = mapped_column(Text, nullable=False)  # buy | sell
    quantity: Mapped[Decimal] = mapped_column(Numeric(24, 8), nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(20, 8), nullable=False)
    transacted_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
