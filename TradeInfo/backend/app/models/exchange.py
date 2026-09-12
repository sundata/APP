from sqlalchemy import JSON, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Exchange(Base):
    __tablename__ = "exchanges"

    exchange_id: Mapped[str] = mapped_column(Text, primary_key=True)
    mic: Mapped[str] = mapped_column(Text, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    country: Mapped[str] = mapped_column(Text, nullable=False)
    timezone: Mapped[str] = mapped_column(Text, nullable=False)  # IANA, e.g. America/New_York
    currency: Mapped[str] = mapped_column(Text, nullable=False)
    # [0..6] Mon..Sun trading days, e.g. [0,1,2,3,4]
    trading_weekdays: Mapped[list[int]] = mapped_column(JSON, nullable=False)
    # Local-time session windows [["09:30","16:00"], ...]; supports lunch breaks (TSE/HKEX/SSE/SZSE)
    sessions: Mapped[list[list[str]]] = mapped_column(JSON, nullable=False)
