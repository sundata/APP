"""pg_trgm extension + trigram indexes for search (PostgreSQL only)

Revision ID: 0011
Revises: 0010
Create Date: 2026-09-11

"""

from alembic import op

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return  # sqlite dev/test fallback uses ILIKE
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.execute(
        "CREATE INDEX ix_assets_name_trgm ON assets USING gin (name gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX ix_assets_symbol_trgm ON assets USING gin (symbol gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX ix_asset_aliases_trgm ON asset_aliases "
        "USING gin (alias gin_trgm_ops)"
    )


def downgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("DROP INDEX IF EXISTS ix_asset_aliases_trgm")
    op.execute("DROP INDEX IF EXISTS ix_assets_symbol_trgm")
    op.execute("DROP INDEX IF EXISTS ix_assets_name_trgm")
