import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, Text, false
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class DataSource(Base):
    """Data source registry (REQUIREMENTS §17).

    Compliance gate (DATA_SOURCE_COMPLIANCE.md): a source may only be
    `enabled=true` when `terms_reviewed=true`. Exception: `collection_type=
    'internal'` (mock/self-generated feeds used for development).
    """

    __tablename__ = "data_sources"

    source_id: Mapped[str] = mapped_column(Text, primary_key=True)
    source_name: Mapped[str] = mapped_column(Text, nullable=False)
    base_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    data_type: Mapped[str] = mapped_column(
        Text, nullable=False
    )  # quote | news | calendar | fundamental | reference
    collection_type: Mapped[str] = mapped_column(
        Text, nullable=False
    )  # api | rss | scraper(non-quote) | internal
    license_status: Mapped[str] = mapped_column(Text, nullable=False)
    robots_status: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    terms_reviewed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=false()
    )
    refresh_interval: Mapped[int] = mapped_column(Integer, nullable=False)  # seconds
    # mandated delay per source license (e.g. 15 for delayed equity feeds); 0 = live
    delay_minutes: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    priority: Mapped[int] = mapped_column(Integer, nullable=False, server_default="100")
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=false())
    last_success_at: Mapped[Optional[datetime.datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_error: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
