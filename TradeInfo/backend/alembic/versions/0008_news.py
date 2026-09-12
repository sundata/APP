"""news + news_asset_relations

Revision ID: 0008
Revises: 0007
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "news",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("source", sa.Text(), nullable=False),
        sa.Column("source_url", sa.Text(), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("language", sa.Text(), nullable=False, server_default="en"),
        sa.Column("importance_score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("content_hash", sa.Text(), nullable=False),
        sa.Column("norm_title", sa.Text(), nullable=False),
        sa.Column("dedup_group_id", sa.Text(), nullable=False),
        sa.Column(
            "source_id",
            sa.Text(),
            sa.ForeignKey("data_sources.source_id"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_news_published", "news", ["published_at"])
    op.create_index("ix_news_content_hash", "news", ["content_hash"])
    op.create_index("ix_news_norm_title", "news", ["norm_title"])
    op.create_index("ix_news_dedup_group", "news", ["dedup_group_id"])

    op.create_table(
        "news_asset_relations",
        sa.Column("news_id", sa.Text(), sa.ForeignKey("news.id"), primary_key=True),
        sa.Column(
            "asset_id", sa.Text(), sa.ForeignKey("assets.asset_id"), primary_key=True
        ),
    )


def downgrade() -> None:
    op.drop_table("news_asset_relations")
    op.drop_table("news")
