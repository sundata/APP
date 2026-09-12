"""collector_jobs + collector_errors

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "collector_jobs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "source_id",
            sa.Text(),
            sa.ForeignKey("data_sources.source_id"),
            nullable=False,
        ),
        sa.Column("collector_type", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("items_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_collector_jobs_source", "collector_jobs", ["source_id", "started_at"])

    op.create_table(
        "collector_errors",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "job_id",
            sa.Integer(),
            sa.ForeignKey("collector_jobs.id"),
            nullable=True,
        ),
        sa.Column(
            "source_id",
            sa.Text(),
            sa.ForeignKey("data_sources.source_id"),
            nullable=False,
        ),
        sa.Column("error_type", sa.Text(), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_collector_errors_source", "collector_errors", ["source_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_table("collector_errors")
    op.drop_table("collector_jobs")
