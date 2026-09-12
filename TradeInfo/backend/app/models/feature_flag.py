from typing import Any, Optional

from sqlalchemy import JSON, Boolean, Text, false
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class FeatureFlag(Base):
    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(Text, primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=false())
    # Optional (not `dict | None`): must eval under py3.9 for local dev; sandbox runs 3.12.
    rollout: Mapped[Optional[dict[str, Any]]] = mapped_column(JSON, nullable=True)
    description: Mapped[str] = mapped_column(Text, nullable=False, server_default="")
