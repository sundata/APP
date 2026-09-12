import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.db import Base
from app.models.asset import Asset, AssetAlias, AssetIdentifier
from app.seed.assets import _build_assets, seed_assets
from app.seed.exchanges import seed_exchanges

# §7.2A Global Market Summary default set
DEFAULT_12 = {
    "index_us_spx", "index_us_ixic", "index_us_dji",
    "index_jp_n225", "index_au_axjo", "index_hk_hsi", "index_cn_shcomp",
    "cmdty_xauusd", "cmdty_wtiusd",
    "crypto_btcusd", "forex_usdjpy", "forex_audusd",
}


@pytest.fixture()
def session() -> Session:  # type: ignore[misc]
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine) as s:
        seed_exchanges(s)
        s.commit()
        yield s


def test_asset_ids_unique() -> None:
    ids = [r["asset_id"] for r in _build_assets()]
    assert len(ids) == len(set(ids))


def test_seed_covers_home_default_assets(session: Session) -> None:
    seed_assets(session)
    ids = {a.asset_id for a in session.scalars(select(Asset))}
    missing = DEFAULT_12 - ids
    assert not missing, f"missing default assets: {missing}"


def test_each_stock_market_has_20_plus(session: Session) -> None:
    seed_assets(session)
    rows = session.execute(
        select(Asset.country, func.count())
        .where(Asset.asset_type == "stock")
        .group_by(Asset.country)
    ).all()
    counts = dict(rows)
    for cc in ("US", "JP", "AU", "HK", "CN"):
        assert counts.get(cc, 0) >= 20, f"{cc}: {counts.get(cc)}"
    assert counts.get("GB", 0) + counts.get("EU", 0) >= 20


def test_localized_names_and_aliases(session: Session) -> None:
    seed_assets(session)
    toyota = session.get(Asset, "stock_jp_7203")
    assert toyota is not None
    assert toyota.name_i18n["ja"] == "トヨタ自動車"
    moutai = session.get(Asset, "stock_cn_600519")
    assert moutai is not None
    assert moutai.name_i18n["zh"] == "贵州茅台"
    # composite symbol alias exists
    alias = session.scalars(
        select(AssetAlias).where(AssetAlias.alias == "NASDAQ:AAPL")
    ).first()
    assert alias is not None and alias.asset_id == "stock_us_aapl"


def test_identifiers_resolve(session: Session) -> None:
    seed_assets(session)
    ident = session.get(AssetIdentifier, ("isin", "US0378331005"))
    assert ident is not None and ident.asset_id == "stock_us_aapl"
    cb = session.get(AssetIdentifier, ("source:coinbase", "BTC-USD"))
    assert cb is not None and cb.asset_id == "crypto_btcusd"


def test_seed_is_idempotent(session: Session) -> None:
    seed_assets(session)
    seed_assets(session)
    session.commit()
    assert session.scalar(select(func.count()).select_from(Asset)) == len(
        _build_assets()
    )
    alias_count = session.scalar(select(func.count()).select_from(AssetAlias))
    seed_assets(session)
    session.commit()
    assert session.scalar(select(func.count()).select_from(AssetAlias)) == alias_count
