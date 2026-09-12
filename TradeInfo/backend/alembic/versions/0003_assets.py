"""assets + asset_aliases + asset_identifiers

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-11

"""

import sqlalchemy as sa

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "assets",
        sa.Column("asset_id", sa.Text(), primary_key=True),
        sa.Column("symbol", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("name_i18n", sa.JSON(), nullable=False, server_default="{}"),
        sa.Column(
            "exchange_id",
            sa.Text(),
            sa.ForeignKey("exchanges.exchange_id"),
            nullable=True,
        ),
        sa.Column("asset_type", sa.Text(), nullable=False),
        sa.Column("country", sa.Text(), nullable=False),
        sa.Column("currency", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False, server_default="active"),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index("ix_assets_symbol", "assets", ["symbol"])
    op.create_index("ix_assets_exchange", "assets", ["exchange_id"])
    op.create_index("ix_assets_type_country", "assets", ["asset_type", "country"])

    op.create_table(
        "asset_aliases",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "asset_id",
            sa.Text(),
            sa.ForeignKey("assets.asset_id"),
            nullable=False,
        ),
        sa.Column("alias", sa.Text(), nullable=False),
        sa.Column("alias_type", sa.Text(), nullable=False),
        sa.Column("locale", sa.Text(), nullable=True),
        sa.Column("source_id", sa.Text(), nullable=True),
    )
    op.create_index("ix_asset_aliases_alias", "asset_aliases", ["alias"])

    op.create_table(
        "asset_identifiers",
        sa.Column("scheme", sa.Text(), nullable=False),
        sa.Column("value", sa.Text(), nullable=False),
        sa.Column(
            "asset_id",
            sa.Text(),
            sa.ForeignKey("assets.asset_id"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("scheme", "value"),
    )
    op.create_index("ix_asset_identifiers_asset", "asset_identifiers", ["asset_id"])


def downgrade() -> None:
    op.drop_table("asset_identifiers")
    op.drop_table("asset_aliases")
    op.drop_table("assets")
