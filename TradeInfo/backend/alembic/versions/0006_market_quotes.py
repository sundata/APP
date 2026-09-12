"""market_quotes

Revision ID: 0006
Revises: 0005
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "market_quotes",
        sa.Column(
            "asset_id",
            sa.Text(),
            sa.ForeignKey("assets.asset_id"),
            primary_key=True,
        ),
        sa.Column("price", sa.Numeric(20, 8), nullable=False),
        sa.Column("change", sa.Numeric(20, 8), nullable=True),
        sa.Column("change_pct", sa.Numeric(10, 4), nullable=True),
        sa.Column("day_high", sa.Numeric(20, 8), nullable=True),
        sa.Column("day_low", sa.Numeric(20, 8), nullable=True),
        sa.Column("volume", sa.Numeric(24, 4), nullable=True),
        sa.Column("quote_ts", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "source_id",
            sa.Text(),
            sa.ForeignKey("data_sources.source_id"),
            nullable=False,
        ),
        sa.Column("delay_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("market_quotes")
