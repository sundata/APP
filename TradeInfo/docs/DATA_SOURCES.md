# DATA_SOURCES.md — SimpleMarket

`data_sources` 注册表的初始内容。**行情红线（§17）：报价数据只允许优先级 1–3（Official / Exchange / Licensed API）。** 爬虫仅用于明确允许的非行情内容。

状态标记：`EVAL` = 需法务/商务评估；`OK` = 条款允许且已记录（见 DATA_SOURCE_COMPLIANCE.md）；`OFF` = 禁用。

## 1. 行情 Quotes

| data_type | 覆盖 | 候选来源 | collection | license_status | 实时级别 | 备注 |
|---|---|---|---|---|---|---|
| crypto | BTC/ETH 等 | 交易所公开 WS/REST（Coinbase、Binance 公开行情）或聚合商 | streaming API | EVAL（公开 API 通常允许展示，需逐家确认再发布条款） | A Live | MVP 首选，免费且可 streaming |
| forex | 主要货币对 | ECB 参考汇率（免费，日更，Level D）；实时需 licensed vendor | API | EVAL | B/D | MVP 可先用延迟/日更数据，UI 标 Delayed |
| index | 全球主要指数 | licensed vendor（候选：Polygon、Tiingo、Twelve Data、Finnhub 等） | API | EVAL | B | 指数授权通常独立于个股 |
| stock_us | NYSE/NASDAQ/AMEX | licensed vendor 同上 | API | EVAL | B（15m delay 常见） | 多数 vendor 低价档为延迟数据，UI 必须标 Delayed 15m |
| stock_jp | TSE/JPX | licensed vendor | API | EVAL | B | JPX 数据授权严格 |
| stock_hk | HKEX | licensed vendor | API | EVAL | B | HKEX 许可费较高，评估是否 MVP 纳入 |
| stock_cn | SSE/SZSE | licensed vendor | API | EVAL | B | **专项许可评估（§44），高风险** |
| stock_au / stock_eu | ASX / LSE / Euronext | licensed vendor | API | EVAL | B | 同上 |
| commodity | Gold/WTI 等 | licensed vendor | API | EVAL | B | |
| bond_yield | 国债收益率 | 官方免费源可覆盖部分：US Treasury（daily）、各国财务省 | API | D | | MVP 可行；实时 yield 需 vendor |
| fx_rates（组合换算） | 全货币对 | ECB / vendor | API | D | | Phase 1.5+ |

**决策点（阻塞 Phase 1）**：选定一家覆盖多市场的 licensed vendor 作为主源；crypto/部分 bond yield 可用免费官方源先行。

## 2. 新闻 News

| 来源类型 | 示例 | collection | license_status |
|---|---|---|---|
| 官方机构/央行 | Fed、ECB、BOJ、RBA、BLS 新闻稿 RSS | RSS | EVAL（政府机构多为公开，仍需记录） |
| 交易所公告 | exchange RSS / API | RSS/API | EVAL |
| 公司公告 | IR RSS（EDGAR 等公开 filing API） | API/RSS | EVAL |
| 财经媒体 | 各家 RSS | RSS | EVAL —— 只存标题+摘要+链接（§13），逐家审 ToS |
| licensed news API | 备选 | API | EVAL |

去重与打分按 §34/§35 实现，与来源无关。

## 3. 财经日历 Calendar

| 事件 | 来源 | collection |
|---|---|---|
| 央行动态（Fed/ECB/BOJ/RBA 利率决议） | 官方公布日程 | API/结构化采集（EVAL） |
| 宏观数据（CPI/GDP/就业） | BLS、各国统计局官方发布 | API（EVAL） |
| 备选 | licensed calendar vendor | API |

## 4. 参考数据 Reference

| 数据 | 来源 |
|---|---|
| 交易所/MIC/时区 | ISO 10383 (MIC list)、exchange 官网 |
| 交易日历/假日 | exchange 官方 + `market_calendars` 表 |
| 资产主数据 | licensed vendor 的 reference endpoint 优先；symbol/ISIN/FIGI 进 `asset_identifiers` |
| Fundamentals（P/E、EPS、市值） | licensed vendor；Level D 日更 |

## 5. 采集器映射（§19）

| Collector | 来源类别 | 调度 |
|---|---|---|
| MarketCollector | quotes 各行 | streaming（有 WS）或 5–30s 轮询 |
| NewsCollector | RSS/API | 1–5 min |
| CalendarCollector | 官方日程 | 15–60 min |
| FundamentalCollector | vendor reference | daily |
| ReferenceCollector | MIC/假日/asset master | weekly/manual |

每个源在 `data_sources` 中登记后才允许采集（§17）；`enabled=false` 即停采。
