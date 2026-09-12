"""push_subscriptions

Revision ID: 0017
Revises: 0016
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0017"
down_revision = "0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "push_subscriptions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("platform", sa.Text(), nullable=False),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column("keys", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_push_subs_user", "push_subscriptions", ["user_id"])
    op.create_index(
        "ix_push_subs_token", "push_subscriptions", ["token"], unique=True
    )


def downgrade() -> None:
    op.drop_table("push_subscriptions")
