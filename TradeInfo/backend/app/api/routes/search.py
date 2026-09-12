"""Asset search (REQUIREMENTS §12, API.md §3).

Match surface: symbol, name, multilingual aliases (asset_aliases),
name_i18n values, and identifiers (asset_identifiers: ISIN/FIGI/…).
PostgreSQL adds pg_trgm fuzzy matching (migration 0011); SQLite dev
falls back to ILIKE. Ranking: exact > prefix/identifier > substring.
"""

from typing import Any

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import Text, cast, func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_session, set_rate_limit_headers
from app.api.errors import err
from app.models.asset import Asset, AssetAlias, AssetIdentifier
from app.schemas import SearchItem

router = APIRouter(tags=["search"])

# display order hint: user's own assets first, then broad classes
_TYPE_RANK = {
    "stock": 0,
    "etf": 1,
    "index": 2,
    "crypto": 3,
    "forex": 4,
    "commodity": 5,
    "bond_yield": 6,
}


def _score(
    asset: Asset, q: str, alias_hit: bool, ident_hit: bool
) -> tuple[int, int, str]:
    ql = q.lower()
    if asset.symbol.lower() == ql or asset.name.lower() == ql:
        rank = 0
    elif ident_hit or asset.symbol.lower().startswith(ql):
        rank = 1
    elif alias_hit or ql in asset.name.lower():
        rank = 2
    else:  # trigram/fuzzy hit (PG only) or weak match
        rank = 3
    return (rank, _TYPE_RANK.get(asset.asset_type, 9), asset.symbol)


@router.get("/search")
def search(
    response: Response,
    q: str = Query(..., min_length=1),
    limit: int = Query(20, ge=1, le=50),
    session: Session = Depends(get_session),
) -> dict[str, Any]:
    q = q.strip()
    if not q:
        return err(400, "bad_request", "q must not be empty")  # type: ignore[return-value]
    pattern = f"%{q}%"

    conds = or_(
        Asset.name.ilike(pattern),
        Asset.symbol.ilike(pattern),
        cast(Asset.name_i18n, Text).ilike(pattern),
        Asset.asset_id.in_(
            select(AssetAlias.asset_id).where(AssetAlias.alias.ilike(pattern))
        ),
        Asset.asset_id.in_(
            select(AssetIdentifier.asset_id).where(
                AssetIdentifier.value.ilike(pattern)
            )
        ),
    )
    if session.bind and session.bind.dialect.name == "postgresql":
        conds = or_(
            conds,
            func.similarity(Asset.name, q) > 0.25,
            func.similarity(Asset.symbol, q) > 0.3,
            Asset.asset_id.in_(
                select(AssetAlias.asset_id).where(
                    func.similarity(AssetAlias.alias, q) > 0.3
                )
            ),
        )

    # fetch extra candidates, rank in Python (dialect-agnostic ordering)
    rows = list(session.scalars(select(Asset).where(conds).limit(limit * 4)))

    cand_ids = [a.asset_id for a in rows]
    alias_hits = set(
        session.scalars(
            select(AssetAlias.asset_id).where(
                AssetAlias.asset_id.in_(cand_ids),
                AssetAlias.alias.ilike(pattern),
            )
        )
    )
    ident_hits = set(
        session.scalars(
            select(AssetIdentifier.asset_id).where(
                AssetIdentifier.asset_id.in_(cand_ids),
                AssetIdentifier.value.ilike(pattern),
            )
        )
    )

    rows.sort(
        key=lambda a: _score(a, q, a.asset_id in alias_hits, a.asset_id in ident_hits)
    )
    rows = rows[:limit]

    set_rate_limit_headers(response)
    return {
        "items": [
            SearchItem(
                asset_id=a.asset_id,
                symbol=a.symbol,
                name=a.name,
                asset_type=a.asset_type,
                exchange_id=a.exchange_id,
                currency=a.currency,
            ).model_dump()
            for a in rows
        ]
    }
