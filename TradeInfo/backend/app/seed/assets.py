"""MVP asset master seed (REQUIREMENTS §7.2A, §24, MVP_TASKS T03).

asset_id convention: {asset_type}_{country}_{symbol_lower}
  - stock_us_aapl, index_jp_n225
  - 24/7 markets use no country segment: crypto_btcusd, forex_usdjpy,
    cmdty_xauusd, yield_us10y
"""

from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.asset import Asset, AssetAlias, AssetIdentifier

# (symbol, name, exchange_id, country, currency, name_i18n)
_STOCKS: list[tuple[str, str, str, str, str, dict[str, str]]] = [
    # ---- US (NASDAQ / NYSE / AMEX) ----
    ("AAPL", "Apple Inc.", "NASDAQ", "US", "USD", {}),
    ("MSFT", "Microsoft Corp.", "NASDAQ", "US", "USD", {}),
    ("NVDA", "NVIDIA Corp.", "NASDAQ", "US", "USD", {}),
    ("AMZN", "Amazon.com Inc.", "NASDAQ", "US", "USD", {}),
    ("GOOGL", "Alphabet Inc. Class A", "NASDAQ", "US", "USD", {}),
    ("META", "Meta Platforms Inc.", "NASDAQ", "US", "USD", {}),
    ("TSLA", "Tesla Inc.", "NASDAQ", "US", "USD", {}),
    ("AVGO", "Broadcom Inc.", "NASDAQ", "US", "USD", {}),
    ("NFLX", "Netflix Inc.", "NASDAQ", "US", "USD", {}),
    ("AMD", "Advanced Micro Devices Inc.", "NASDAQ", "US", "USD", {}),
    ("CRM", "Salesforce Inc.", "NYSE", "US", "USD", {}),
    ("ORCL", "Oracle Corp.", "NYSE", "US", "USD", {}),
    ("JPM", "JPMorgan Chase & Co.", "NYSE", "US", "USD", {}),
    ("V", "Visa Inc.", "NYSE", "US", "USD", {}),
    ("UNH", "UnitedHealth Group Inc.", "NYSE", "US", "USD", {}),
    ("XOM", "Exxon Mobil Corp.", "NYSE", "US", "USD", {}),
    ("LLY", "Eli Lilly and Co.", "NYSE", "US", "USD", {}),
    ("COST", "Costco Wholesale Corp.", "NASDAQ", "US", "USD", {}),
    ("HD", "Home Depot Inc.", "NYSE", "US", "USD", {}),
    ("WMT", "Walmart Inc.", "NYSE", "US", "USD", {}),
    # ---- JP (TSE) ----
    ("7203", "Toyota Motor Corp.", "TSE", "JP", "JPY", {"ja": "トヨタ自動車", "zh": "丰田汽车"}),
    ("6758", "Sony Group Corp.", "TSE", "JP", "JPY", {"ja": "ソニーグループ", "zh": "索尼集团"}),
    ("8306", "Mitsubishi UFJ Financial Group", "TSE", "JP", "JPY",
     {"ja": "三菱UFJフィナンシャル・グループ"}),
    ("9984", "SoftBank Group Corp.", "TSE", "JP", "JPY", {"ja": "ソフトバンクグループ"}),
    ("6861", "Keyence Corp.", "TSE", "JP", "JPY", {"ja": "キーエンス"}),
    ("7974", "Nintendo Co., Ltd.", "TSE", "JP", "JPY", {"ja": "任天堂", "zh": "任天堂"}),
    ("6501", "Hitachi, Ltd.", "TSE", "JP", "JPY", {"ja": "日立製作所"}),
    ("9433", "KDDI Corp.", "TSE", "JP", "JPY", {"ja": "KDDI"}),
    ("4063", "Shin-Etsu Chemical Co.", "TSE", "JP", "JPY", {"ja": "信越化学工業"}),
    ("8001", "ITOCHU Corp.", "TSE", "JP", "JPY", {"ja": "伊藤忠商事"}),
    ("8316", "Sumitomo Mitsui Financial Group", "TSE", "JP", "JPY",
     {"ja": "三井住友フィナンシャルグループ"}),
    ("6902", "DENSO Corp.", "TSE", "JP", "JPY", {"ja": "デンソー"}),
    ("8035", "Tokyo Electron Ltd.", "TSE", "JP", "JPY", {"ja": "東京エレクトロン"}),
    ("4519", "Chugai Pharmaceutical Co.", "TSE", "JP", "JPY", {"ja": "中外製薬"}),
    ("6367", "Daikin Industries, Ltd.", "TSE", "JP", "JPY", {"ja": "ダイキン工業"}),
    ("7011", "Mitsubishi Heavy Industries", "TSE", "JP", "JPY", {"ja": "三菱重工業"}),
    ("2914", "Japan Tobacco Inc.", "TSE", "JP", "JPY", {"ja": "日本たばこ産業"}),
    ("3382", "Seven & i Holdings Co.", "TSE", "JP", "JPY", {"ja": "セブン&アイ・ホールディングス"}),
    ("9202", "ANA Holdings Inc.", "TSE", "JP", "JPY", {"ja": "ANAホールディングス"}),
    ("5401", "Nippon Steel Corp.", "TSE", "JP", "JPY", {"ja": "日本製鉄"}),
    # ---- AU (ASX) ----
    ("BHP", "BHP Group Ltd.", "ASX", "AU", "AUD", {}),
    ("CBA", "Commonwealth Bank of Australia", "ASX", "AU", "AUD", {}),
    ("CSL", "CSL Ltd.", "ASX", "AU", "AUD", {}),
    ("NAB", "National Australia Bank", "ASX", "AU", "AUD", {}),
    ("WBC", "Westpac Banking Corp.", "ASX", "AU", "AUD", {}),
    ("ANZ", "ANZ Group Holdings", "ASX", "AU", "AUD", {}),
    ("FMG", "Fortescue Ltd.", "ASX", "AU", "AUD", {}),
    ("WES", "Wesfarmers Ltd.", "ASX", "AU", "AUD", {}),
    ("MQG", "Macquarie Group Ltd.", "ASX", "AU", "AUD", {}),
    ("GMG", "Goodman Group", "ASX", "AU", "AUD", {}),
    ("WOW", "Woolworths Group Ltd.", "ASX", "AU", "AUD", {}),
    ("TLS", "Telstra Group Ltd.", "ASX", "AU", "AUD", {}),
    ("RIO", "Rio Tinto Ltd.", "ASX", "AU", "AUD", {}),
    ("WDS", "Woodside Energy Group", "ASX", "AU", "AUD", {}),
    ("TCL", "Transurban Group", "ASX", "AU", "AUD", {}),
    ("STO", "Santos Ltd.", "ASX", "AU", "AUD", {}),
    ("QBE", "QBE Insurance Group", "ASX", "AU", "AUD", {}),
    ("ALL", "Aristocrat Leisure Ltd.", "ASX", "AU", "AUD", {}),
    ("REA", "REA Group Ltd.", "ASX", "AU", "AUD", {}),
    ("XRO", "Xero Ltd.", "ASX", "AU", "AUD", {}),
    # ---- HK (HKEX) ----
    ("0700", "Tencent Holdings Ltd.", "HKEX", "HK", "HKD", {"zh": "腾讯控股"}),
    ("9988", "Alibaba Group Holding", "HKEX", "HK", "HKD", {"zh": "阿里巴巴"}),
    ("0941", "China Mobile Ltd.", "HKEX", "HK", "HKD", {"zh": "中国移动"}),
    ("0939", "China Construction Bank", "HKEX", "HK", "HKD", {"zh": "建设银行"}),
    ("1299", "AIA Group Ltd.", "HKEX", "HK", "HKD", {"zh": "友邦保险"}),
    ("2318", "Ping An Insurance (H)", "HKEX", "HK", "HKD", {"zh": "中国平安"}),
    ("0388", "Hong Kong Exchanges and Clearing", "HKEX", "HK", "HKD", {"zh": "香港交易所"}),
    ("0005", "HSBC Holdings plc", "HKEX", "HK", "HKD", {"zh": "汇丰控股"}),
    ("3690", "Meituan", "HKEX", "HK", "HKD", {"zh": "美团"}),
    ("1810", "Xiaomi Corp.", "HKEX", "HK", "HKD", {"zh": "小米集团"}),
    ("1398", "ICBC (H)", "HKEX", "HK", "HKD", {"zh": "工商银行"}),
    ("0883", "CNOOC Ltd.", "HKEX", "HK", "HKD", {"zh": "中国海洋石油"}),
    ("0001", "CK Hutchison Holdings", "HKEX", "HK", "HKD", {"zh": "长和"}),
    ("0016", "Sun Hung Kai Properties", "HKEX", "HK", "HKD", {"zh": "新鸿基地产"}),
    ("2020", "ANTA Sports Products", "HKEX", "HK", "HKD", {"zh": "安踏体育"}),
    ("9618", "JD.com Inc.", "HKEX", "HK", "HKD", {"zh": "京东集团"}),
    ("9999", "NetEase Inc.", "HKEX", "HK", "HKD", {"zh": "网易"}),
    ("1024", "Kuaishou Technology", "HKEX", "HK", "HKD", {"zh": "快手"}),
    ("2899", "Zijin Mining Group (H)", "HKEX", "HK", "HKD", {"zh": "紫金矿业"}),
    ("1211", "BYD Co. (H)", "HKEX", "HK", "HKD", {"zh": "比亚迪股份"}),
    # ---- CN (SSE / SZSE) ----
    ("600519", "Kweichow Moutai Co.", "SSE", "CN", "CNY", {"zh": "贵州茅台"}),
    ("601318", "Ping An Insurance (A)", "SSE", "CN", "CNY", {"zh": "中国平安"}),
    ("600036", "China Merchants Bank", "SSE", "CN", "CNY", {"zh": "招商银行"}),
    ("601398", "ICBC (A)", "SSE", "CN", "CNY", {"zh": "工商银行"}),
    ("600900", "China Yangtze Power", "SSE", "CN", "CNY", {"zh": "长江电力"}),
    ("601899", "Zijin Mining Group (A)", "SSE", "CN", "CNY", {"zh": "紫金矿业"}),
    ("600276", "Jiangsu Hengrui Pharmaceuticals", "SSE", "CN", "CNY", {"zh": "恒瑞医药"}),
    ("601012", "LONGi Green Energy", "SSE", "CN", "CNY", {"zh": "隆基绿能"}),
    ("603259", "WuXi AppTec Co.", "SSE", "CN", "CNY", {"zh": "药明康德"}),
    ("600030", "CITIC Securities", "SSE", "CN", "CNY", {"zh": "中信证券"}),
    ("000858", "Wuliangye Yibin Co.", "SZSE", "CN", "CNY", {"zh": "五粮液"}),
    ("300750", "CATL", "SZSE", "CN", "CNY", {"zh": "宁德时代"}),
    ("002594", "BYD Co. (A)", "SZSE", "CN", "CNY", {"zh": "比亚迪"}),
    ("000333", "Midea Group", "SZSE", "CN", "CNY", {"zh": "美的集团"}),
    ("300059", "East Money Information", "SZSE", "CN", "CNY", {"zh": "东方财富"}),
    ("002415", "Hikvision", "SZSE", "CN", "CNY", {"zh": "海康威视"}),
    ("000651", "Gree Electric Appliances", "SZSE", "CN", "CNY", {"zh": "格力电器"}),
    ("300760", "Mindray Medical", "SZSE", "CN", "CNY", {"zh": "迈瑞医疗"}),
    ("601888", "China Tourism Group Duty Free", "SSE", "CN", "CNY", {"zh": "中国中免"}),
    ("600585", "Anhui Conch Cement", "SSE", "CN", "CNY", {"zh": "海螺水泥"}),
    # ---- GB (LSE) ----
    ("SHEL", "Shell plc", "LSE", "GB", "GBP", {}),
    ("AZN", "AstraZeneca plc", "LSE", "GB", "GBP", {}),
    ("HSBA", "HSBC Holdings plc", "LSE", "GB", "GBP", {}),
    ("ULVR", "Unilever plc", "LSE", "GB", "GBP", {}),
    ("BP", "BP plc", "LSE", "GB", "GBP", {}),
    ("GSK", "GSK plc", "LSE", "GB", "GBP", {}),
    ("DGE", "Diageo plc", "LSE", "GB", "GBP", {}),
    ("BATS", "British American Tobacco", "LSE", "GB", "GBP", {}),
    ("LSEG", "London Stock Exchange Group", "LSE", "GB", "GBP", {}),
    ("RIO", "Rio Tinto plc", "LSE", "GB", "GBP", {}),
    # ---- EU (Euronext) ----
    ("MC", "LVMH Moët Hennessy", "EURONEXT", "EU", "EUR", {}),
    ("OR", "L'Oréal S.A.", "EURONEXT", "EU", "EUR", {}),
    ("TTE", "TotalEnergies SE", "EURONEXT", "EU", "EUR", {}),
    ("SAN", "Sanofi S.A.", "EURONEXT", "EU", "EUR", {}),
    ("AIR", "Airbus SE", "EURONEXT", "EU", "EUR", {}),
    ("ASML", "ASML Holding N.V.", "EURONEXT", "EU", "EUR", {}),
    ("SU", "Schneider Electric SE", "EURONEXT", "EU", "EUR", {}),
    ("BN", "Danone S.A.", "EURONEXT", "EU", "EUR", {}),
    ("EL", "EssilorLuxottica S.A.", "EURONEXT", "EU", "EUR", {}),
    ("SAF", "Safran S.A.", "EURONEXT", "EU", "EUR", {}),
]

# (symbol, name, exchange_id or None, country, currency, asset_type)
_OTHERS: list[tuple[str, str, Optional[str], str, str, str]] = [
    # Indices — linked to home exchange for market-status/freshness (§39)
    ("SPX", "S&P 500", "NYSE", "US", "USD", "index"),
    ("IXIC", "NASDAQ Composite", "NASDAQ", "US", "USD", "index"),
    ("DJI", "Dow Jones Industrial Average", "NYSE", "US", "USD", "index"),
    ("N225", "Nikkei 225", "TSE", "JP", "JPY", "index"),
    ("AXJO", "S&P/ASX 200", "ASX", "AU", "AUD", "index"),
    ("HSI", "Hang Seng Index", "HKEX", "HK", "HKD", "index"),
    ("SHCOMP", "Shanghai Composite", "SSE", "CN", "CNY", "index"),
    ("FTSE", "FTSE 100", "LSE", "GB", "GBP", "index"),
    ("SX5E", "EURO STOXX 50", "EURONEXT", "EU", "EUR", "index"),
    # Forex (24/7, no exchange)
    ("USDJPY", "US Dollar / Japanese Yen", None, "", "JPY", "forex"),
    ("AUDUSD", "Australian Dollar / US Dollar", None, "", "USD", "forex"),
    ("EURUSD", "Euro / US Dollar", None, "", "USD", "forex"),
    ("GBPUSD", "British Pound / US Dollar", None, "", "USD", "forex"),
    ("USDCNH", "US Dollar / Offshore Yuan", None, "", "CNH", "forex"),
    ("USDCHF", "US Dollar / Swiss Franc", None, "", "CHF", "forex"),
    ("USDCAD", "US Dollar / Canadian Dollar", None, "", "CAD", "forex"),
    ("NZDUSD", "New Zealand Dollar / US Dollar", None, "", "USD", "forex"),
    ("EURJPY", "Euro / Japanese Yen", None, "", "JPY", "forex"),
    ("GBPJPY", "British Pound / Japanese Yen", None, "", "JPY", "forex"),
    # Crypto (24/7)
    ("BTCUSD", "Bitcoin / US Dollar", None, "", "USD", "crypto"),
    ("ETHUSD", "Ethereum / US Dollar", None, "", "USD", "crypto"),
    ("SOLUSD", "Solana / US Dollar", None, "", "USD", "crypto"),
    ("XRPUSD", "XRP / US Dollar", None, "", "USD", "crypto"),
    ("ADAUSD", "Cardano / US Dollar", None, "", "USD", "crypto"),
    ("DOGEUSD", "Dogecoin / US Dollar", None, "", "USD", "crypto"),
    # Commodities
    ("XAUUSD", "Gold Spot / US Dollar", None, "", "USD", "commodity"),
    ("WTIUSD", "WTI Crude Oil", None, "", "USD", "commodity"),
    ("XAGUSD", "Silver Spot / US Dollar", None, "", "USD", "commodity"),
    ("BRNUSD", "Brent Crude Oil", None, "", "USD", "commodity"),
    ("HGUSD", "Copper", None, "", "USD", "commodity"),
    ("NGUSD", "Natural Gas", None, "", "USD", "commodity"),
    # Bond yields (Level D)
    ("US10Y", "US 10-Year Treasury Yield", None, "US", "%", "bond_yield"),
    ("JP10Y", "Japan 10-Year Government Bond Yield", None, "JP", "%", "bond_yield"),
    ("AU10Y", "Australia 10-Year Government Bond Yield", None, "AU", "%", "bond_yield"),
    ("GB10Y", "UK 10-Year Gilt Yield", None, "GB", "%", "bond_yield"),
    # ETFs
    ("SPY", "SPDR S&P 500 ETF Trust", "AMEX", "US", "USD", "etf"),
    ("QQQ", "Invesco QQQ Trust", "NASDAQ", "US", "USD", "etf"),
    ("VTI", "Vanguard Total Stock Market ETF", "NYSE", "US", "USD", "etf"),
    ("1321", "NEXT FUNDS Nikkei 225 ETF", "TSE", "JP", "JPY", "etf"),
    ("2800", "Tracker Fund of Hong Kong", "HKEX", "HK", "HKD", "etf"),
    ("510300", "CSI 300 ETF", "SSE", "CN", "CNY", "etf"),
]

# Structured identifiers: (scheme, value, asset_id)
_IDENTIFIERS: list[tuple[str, str, str]] = [
    ("isin", "US0378331005", "stock_us_aapl"),
    ("isin", "US5949181045", "stock_us_msft"),
    ("isin", "US67066G1040", "stock_us_nvda"),
    ("isin", "JP3633400001", "stock_jp_7203"),
    ("isin", "JP3435000009", "stock_jp_6758"),
    ("isin", "KYG875721634", "stock_hk_0700"),
    ("isin", "KYG017191142", "stock_hk_9988"),
    ("isin", "CNE0000018R8", "stock_cn_600519"),
    ("isin", "AU000000BHP4", "stock_au_bhp"),
    ("isin", "AU000000CBA7", "stock_au_cba"),
    # per-source symbol mapping example (§24)
    ("source:coinbase", "BTC-USD", "crypto_btcusd"),
    ("source:coinbase", "ETH-USD", "crypto_ethusd"),
]


def _asset_id(asset_type: str, country: str, symbol: str) -> str:
    prefix = "cmdty" if asset_type == "commodity" else asset_type
    if country:
        return f"{prefix}_{country.lower()}_{symbol.lower()}"
    return f"{prefix}_{symbol.lower()}"


def _build_assets() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for symbol, name, exch, country, ccy, i18n in _STOCKS:
        rows.append(
            {
                "asset_id": _asset_id("stock", country, symbol),
                "symbol": symbol,
                "name": name,
                "name_i18n": i18n,
                "exchange_id": exch,
                "asset_type": "stock",
                "country": country,
                "currency": ccy,
            }
        )
    for symbol, name, exch_id, country, ccy, atype in _OTHERS:
        rows.append(
            {
                "asset_id": _asset_id(atype, country, symbol),
                "symbol": symbol,
                "name": name,
                "name_i18n": {},
                "exchange_id": exch_id,
                "asset_type": atype,
                "country": country,
                "currency": ccy,
            }
        )
    return rows


def _build_aliases(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    aliases: list[dict[str, Any]] = []
    for r in rows:
        # composite exchange-qualified symbol, e.g. "NASDAQ:AAPL" (§24)
        if r["exchange_id"]:
            aliases.append(
                {
                    "asset_id": r["asset_id"],
                    "alias": f"{r['exchange_id']}:{r['symbol']}",
                    "alias_type": "symbol",
                    "locale": None,
                }
            )
        for locale, localized in r["name_i18n"].items():
            aliases.append(
                {
                    "asset_id": r["asset_id"],
                    "alias": localized,
                    "alias_type": "name",
                    "locale": locale,
                }
            )
    return aliases


def seed_assets(session: Session) -> int:
    """Idempotent upsert of assets + aliases + identifiers. Returns asset count."""
    rows = _build_assets()
    for row in rows:
        session.merge(Asset(**row))

    # aliases: wipe + rebuild keeps idempotent without a natural key
    session.query(AssetAlias).delete()
    for alias in _build_aliases(rows):
        session.add(AssetAlias(**alias))

    for scheme, value, asset_id in _IDENTIFIERS:
        session.merge(AssetIdentifier(scheme=scheme, value=value, asset_id=asset_id))

    return len(rows)
