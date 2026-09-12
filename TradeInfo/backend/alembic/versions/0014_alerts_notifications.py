"""price_alerts + alert_trigger_log + notifications

Revision ID: 0014
Revises: 0013
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "price_alerts",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "asset_id", sa.Text(), sa.ForeignKey("assets.asset_id"), nullable=False
        ),
        sa.Column("direction", sa.Text(), nullable=False),
        sa.Column("price", sa.Numeric(20, 8), nullable=False),
        sa.Column("channel", sa.Text(), nullable=False, server_default="push"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("last_triggered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_price_alerts_asset", "price_alerts", ["asset_id", "enabled"]
    )
    op.create_index("ix_price_alerts_user", "price_alerts", ["user_id"])

    op.create_table(
        "alert_trigger_log",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "alert_id",
            sa.Text(),
            sa.ForeignKey("price_alerts.id"),
            nullable=False,
        ),
        sa.Column("triggered_price", sa.Numeric(20, 8), nullable=False),
        sa.Column("quote_ts", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("data", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_notifications_user", "notifications", ["user_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_table("notifications")
    op.drop_table("alert_trigger_log")
    op.drop_table("price_alerts")
