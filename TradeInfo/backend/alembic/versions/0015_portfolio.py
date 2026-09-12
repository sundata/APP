"""portfolio_transactions

Revision ID: 0015
Revises: 0014
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0015"
down_revision = "0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "portfolio_transactions",
        sa.Column("id", sa.Text(), primary_key=True),
        sa.Column("user_id", sa.Text(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "asset_id", sa.Text(), sa.ForeignKey("assets.asset_id"), nullable=False
        ),
        sa.Column("side", sa.Text(), nullable=False),
        sa.Column("quantity", sa.Numeric(24, 8), nullable=False),
        sa.Column("price", sa.Numeric(20, 8), nullable=False),
        sa.Column("transacted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_portfolio_tx_user", "portfolio_transactions", ["user_id", "transacted_at"]
    )


def downgrade() -> None:
    op.drop_table("portfolio_transactions")
