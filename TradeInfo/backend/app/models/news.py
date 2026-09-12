import datetime
from typing import Optional

from sqlalchemy import JSON, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class News(Base):
    """News metadata only (REQUIREMENTS §13): title + summary + source link.
    Full text is never stored or republished (§44 red line)."""

    __tablename__ = "news"
    __table_args__ = (
        Index("ix_news_published", "published_at"),
        Index("ix_news_content_hash", "content_hash"),
        Index("ix_news_norm_title", "norm_title"),
        Index("ix_news_dedup_group", "dedup_group_id"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)  # uuid
    title: Mapped[str] = mapped_column(Text, nullable=False)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    source_url: Mapped[str] = mapped_column(Text, nullable=False)
    published_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    language: Mapped[str] = mapped_column(Text, nullable=False, server_default="en")
    importance_score: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    # §35 dedup: exact-hash key + normalized title + group linkage
    content_hash: Mapped[str] = mapped_column(Text, nullable=False)
    norm_title: Mapped[str] = mapped_column(Text, nullable=False)
    dedup_group_id: Mapped[str] = mapped_column(Text, nullable=False)
    categories: Mapped[list[str]] = mapped_column(
        JSON, nullable=False, server_default="[]"
    )  # macro | earnings | crypto | company | ...
    source_id: Mapped[Optional[str]] = mapped_column(
        Text, ForeignKey("data_sources.source_id"), nullable=True
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class NewsAssetRelation(Base):
    __tablename__ = "news_asset_relations"

    news_id: Mapped[str] = mapped_column(
        Text, ForeignKey("news.id"), primary_key=True
    )
    asset_id: Mapped[str] = mapped_column(
        Text, ForeignKey("assets.asset_id"), primary_key=True
    )
