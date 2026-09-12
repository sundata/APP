import datetime
from typing import Any, Optional

from sqlalchemy import JSON, ForeignKey, Index, Integer, Text, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Asset(Base):
    """Unified asset master (REQUIREMENTS §24). asset_id = {type}_{country}_{symbol}."""

    __tablename__ = "assets"

    asset_id: Mapped[str] = mapped_column(Text, primary_key=True)
    symbol: Mapped[str] = mapped_column(Text, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    # localized names: {"ja": "トヨタ自動車", "zh": "丰田汽车"}
    name_i18n: Mapped[dict[str, Any]] = mapped_column(
        JSON, nullable=False, server_default="{}"
    )
    # NULL for 24/7 markets (forex/crypto/commodity) not tied to an exchange
    exchange_id: Mapped[Optional[str]] = mapped_column(
        Text, ForeignKey("exchanges.exchange_id"), nullable=True
    )
    asset_type: Mapped[str] = mapped_column(
        Text, nullable=False
    )  # stock|etf|index|forex|crypto|commodity|bond_yield
    country: Mapped[str] = mapped_column(Text, nullable=False)
    currency: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    created_at: Mapped[datetime.datetime] = mapped_column(
        server_default=text("CURRENT_TIMESTAMP")
    )


class AssetAlias(Base):
    """Searchable alternate names/symbols incl. localized names (§10, §24)."""

    __tablename__ = "asset_aliases"
    __table_args__ = (Index("ix_asset_aliases_alias", "alias"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), nullable=False
    )
    alias: Mapped[str] = mapped_column(Text, nullable=False)
    alias_type: Mapped[str] = mapped_column(Text, nullable=False)  # name | symbol
    locale: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # logically references data_sources.source_id (table lands in T04); plain Text
    # for now to keep this migration self-contained.
    source_id: Mapped[Optional[str]] = mapped_column(Text, nullable=True)


class AssetIdentifier(Base):
    """Structured identifiers: isin / figi / source:{source_id} (§10 ISIN, §24)."""

    __tablename__ = "asset_identifiers"
    __table_args__ = (Index("ix_asset_identifiers_asset", "asset_id"),)

    scheme: Mapped[str] = mapped_column(Text, primary_key=True)
    value: Mapped[str] = mapped_column(Text, primary_key=True)
    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), nullable=False
    )
