"""exchanges + market_calendars

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "exchanges",
        sa.Column("exchange_id", sa.Text(), primary_key=True),
        sa.Column("mic", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("country", sa.Text(), nullable=False),
        sa.Column("timezone", sa.Text(), nullable=False),
        sa.Column("currency", sa.Text(), nullable=False),
        sa.Column("trading_weekdays", sa.JSON(), nullable=False),
        sa.Column("sessions", sa.JSON(), nullable=False),
    )
    op.create_table(
        "market_calendars",
        sa.Column(
            "exchange_id",
            sa.Text(),
            sa.ForeignKey("exchanges.exchange_id"),
            nullable=False,
        ),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("open_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("close_utc", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_holiday", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.UniqueConstraint(
            "exchange_id", "date", name="uq_market_calendars_exchange_date"
        ),
    )


def downgrade() -> None:
    op.drop_table("market_calendars")
    op.drop_table("exchanges")
