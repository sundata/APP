"""news.categories + markets.category → asset_type is implicit; no schema for it

Revision ID: 0016
Revises: 0015
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0016"
down_revision = "0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "news",
        sa.Column("categories", sa.JSON(), nullable=False, server_default="[]"),
    )


def downgrade() -> None:
    op.drop_column("news", "categories")
