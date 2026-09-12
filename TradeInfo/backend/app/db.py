import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    pass


def get_database_url() -> str:
    return os.environ.get("DATABASE_URL", settings.database_url)


engine = create_engine(get_database_url())
SessionLocal = sessionmaker(bind=engine)
