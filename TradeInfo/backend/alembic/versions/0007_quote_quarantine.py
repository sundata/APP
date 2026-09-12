"""quote_quarantine

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "quote_quarantine",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("asset_id", sa.Text(), nullable=True),
        sa.Column(
            "source_id",
            sa.Text(),
            sa.ForeignKey("data_sources.source_id"),
            nullable=False,
        ),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("quote_ts", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_quote_quarantine_source", "quote_quarantine", ["source_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_table("quote_quarantine")
