from app.db import SessionLocal
from app.seed.assets import seed_assets
from app.seed.data_sources import seed_data_sources
from app.seed.exchanges import seed_exchanges


def main() -> None:
    with SessionLocal() as session:
        exchanges = seed_exchanges(session)
        assets = seed_assets(session)
        sources = seed_data_sources(session)
        session.commit()
    print(
        f"seeded {exchanges} exchanges, {assets} assets, {sources} data sources"
    )


if __name__ == "__main__":
    main()
