from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SIMPLEMARKET_", env_file=".env")

    environment: str = "local"
    database_url: str = (
        "postgresql+psycopg://simplemarket:simplemarket@localhost:5433/simplemarket"
    )
    redis_url: str = "redis://localhost:6379/0"
    # JWT signing secret — dev default; override via SIMPLEMARKET_SECRET_KEY
    secret_key: str = "dev-secret-change-me"
    # OAuth: "mock" (dev) or "real"; comma-separated client IDs for aud checks
    oauth_mode: str = "mock"
    oauth_client_ids: str = ""


settings = Settings()
