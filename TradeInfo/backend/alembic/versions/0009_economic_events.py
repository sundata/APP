"""economic_events

Revision ID: 0009
Revises: 0008
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "economic_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("country", sa.Text(), nullable=False),
        sa.Column("currency", sa.Text(), nullable=False),
        sa.Column("event_name", sa.Text(), nullable=False),
        sa.Column("event_time_utc", sa.DateTime(timezone=True), nullable=False),
        sa.Column("importance", sa.Text(), nullable=False, server_default="medium"),
        sa.Column("actual", sa.Text(), nullable=True),
        sa.Column("forecast", sa.Text(), nullable=True),
        sa.Column("previous", sa.Text(), nullable=True),
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
        sa.UniqueConstraint(
            "country", "event_name", "event_time_utc", name="uq_econ_event"
        ),
    )
    op.create_index("ix_econ_events_time", "economic_events", ["event_time_utc"])
    op.create_index(
        "ix_econ_events_importance", "economic_events", ["importance", "event_time_utc"]
    )


def downgrade() -> None:
    op.drop_table("economic_events")
