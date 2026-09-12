"""Plausible base prices shared by mock collectors and history backfill."""

BASE_PRICES: dict[str, float] = {
    "crypto_btcusd": 65_000.0,
    "crypto_ethusd": 3_400.0,
    "crypto_solusd": 150.0,
    "forex_usdjpy": 155.0,
    "forex_audusd": 0.66,
    "forex_eurusd": 1.08,
    "index_us_spx": 5_900.0,
    "index_us_ixic": 19_000.0,
    "index_us_dji": 43_000.0,
    "index_jp_n225": 39_000.0,
    "cmdty_xauusd": 2_600.0,
    "cmdty_wtiusd": 75.0,
    "stock_us_aapl": 250.0,
    "stock_us_nvda": 180.0,
    "stock_jp_7203": 3_200.0,
}
