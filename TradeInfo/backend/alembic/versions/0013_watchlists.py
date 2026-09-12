"""watchlists + watchlist_items

Revision ID: 0013
Revises: 0012
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "watchlists",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_watchlists_user", "watchlists", ["user_id"])
    op.create_table(
        "watchlist_items",
        sa.Column(
            "watchlist_id",
            sa.Text(),
            sa.ForeignKey("watchlists.id"),
            primary_key=True,
        ),
        sa.Column(
            "asset_id",
            sa.Text(),
            sa.ForeignKey("assets.asset_id"),
            primary_key=True,
        ),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "added_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("watchlist_items")
    op.drop_table("watchlists")
