"""data_sources registry

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "data_sources",
        sa.Column("source_id", sa.Text(), primary_key=True),
        sa.Column("source_name", sa.Text(), nullable=False),
        sa.Column("base_url", sa.Text(), nullable=True),
        sa.Column("data_type", sa.Text(), nullable=False),
        sa.Column("collection_type", sa.Text(), nullable=False),
        sa.Column("license_status", sa.Text(), nullable=False),
        sa.Column("robots_status", sa.Text(), nullable=True),
        sa.Column(
            "terms_reviewed", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
        sa.Column("refresh_interval", sa.Integer(), nullable=False),
        sa.Column("delay_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("last_success_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
    )
    op.create_index("ix_data_sources_type_enabled", "data_sources", ["data_type", "enabled"])


def downgrade() -> None:
    op.drop_table("data_sources")
