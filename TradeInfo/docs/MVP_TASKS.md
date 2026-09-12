# MVP_TASKS.md — SimpleMarket

粒度规则（§52.1）：每个任务 = 一个 session 可完成 = 一个 PR。每任务带验收条件。
依赖列标的是任务编号。

## Phase 1 — Data

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T01 | backend 骨架：FastAPI + Alembic + pytest + ruff/mypy | `pytest` 绿、`alembic upgrade head` 跑通 | — |
| T02 | exchanges + market_calendars 表 + MVP 交易所 seed（§5） | 表存在、含 NYSE/NASDAQ/TSE/ASX/HKEX/SSE/SZSE/LSE/Euronext 时区与开闭市 | T01 |
| T03 | assets + asset_aliases + asset_identifiers + asset seed | §7.2A 默认 12 个资产 + 每市场 ≥20 个代表资产可查 | T02 |
| T04 | data_sources 表 + 注册表 seed（DATA_SOURCES.md 全部条目） | 表结构含 §17 全字段；未评审源 enabled=false | T01 |
| T05 | Collector 框架：retry/timeout/ratelimit/backoff/circuit breaker + collector_jobs/errors 记录 | 单测覆盖；模拟源失败产生 error 记录 | T01 |
| T06 | MarketCollector — crypto 免费源（如 Coinbase 公开 API） | 行情进 raw bucket + normalize 后写 Redis/PG；字段含 ts/source | T04,T05 |
| T07 | Data Processor：校验 §36 八项 + quarantine | 异常 tick 不进 market_quotes，进 quarantine/记录 | T06 |
| T08 | data_freshness_monitor + market_calendars 联动 | 开市超时→stale 标记；闭市不误报 | T02,T07 |
| T09 | NewsCollector ×≥3 RSS 源 + content_hash 去重（§35） | 同源同新闻只存一条，dedup_group 聚合 | T04,T05 |
| T10 | CalendarCollector：官方 High Impact 事件 | economic_events 有 Today+High 可查数据 | T04,T05 |
| T11 | price_history 日线回填脚本 + BigQuery tick sink | 日线可查；tick 落 BQ 分区表 | T06 |

## Phase 2 — Backend

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T12 | openapi.yaml 契约冻结 + Prism mock | mock server 可起，文档与 spec 一致 | — |
| T13 | Auth：register/login/refresh + Google/Apple OAuth | JWT 签发/刷新/吊销；单测覆盖 | T01 |
| T14 | GET /markets /markets/{cat} /assets/{id} | 数据来自 Redis snapshot；带 delay_minutes/quote_ts | T03,T06 |
| T15 | GET /assets/{id}/chart + /news | 各 period 返回；相关新闻 ≤5 | T09,T11 |
| T16 | GET /search（pg_trgm，多语言别名） | `AAPL`/`Apple`/`トヨタ`/`7203` 均命中；P95<500ms | T03 |
| T17 | GET /news ?category= + importance 排序（§34） | 排序含 breaking/source/watchlist/freshness 权重 | T09 |
| T18 | GET /calendar 过滤 | 默认 Today+High；参数可改（AC-007） | T10 |
| T19 | /ws/quotes：snapshot→delta + 心跳 + reconnect | 订阅即收 snapshot；断线重连恢复订阅 | T14 |
| T20 | Auth 用户：watchlists CRUD + items + reorder | ≤200/list 限制；star 加入 <1s（AC-005） | T13,T14 |
| T21 | alerts CRUD + Alert Engine + alert_trigger_log | 行情满足条件→触发→写 log→入通知队列；cooldown 生效 | T13,T19 |
| T22 | portfolio transactions + positions 重算（原币） | 流水→持仓/均价/盈亏正确；单测覆盖边界 | T13,T20 |

## Phase 3 — Web

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T23 | web 骨架：Next.js + TS + i18n + dark mode + Asian color mode | 三语切换；红涨绿跌可切 | T12 |
| T24 | /home（mock 先行） | §7.2 四区块；2.5s LCP；四态完整 | T23 |
| T25 | /markets 分类表格 + sort/filter/favorite | §8 字段齐 | T23,T14 |
| T26 | /asset 详情 + line chart 各周期 | §9；价格 WS 自动更新（AC-002） | T19,T23 |
| T27 | /search 全局搜索 | AC-004；键盘可达 | T16,T23 |
| T28 | /watchlist + /news + /calendar 页 | AC-005/006/007 | T17,T18,T20 |
| T29 | /login + 会话 + 设置页 | 三登录方式；设置跨端同步 | T13 |
| T30 | SEO：asset 页 SSR/OG/结构化数据；用户页 noindex | §63 检查单过 | T26 |
| T31 | Playwright E2E（§55 八条路径） | CI 全绿 | T24–T29 |

## Phase 4 — Mobile

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T32 | Flutter 骨架 + 5-tab + 主题/i18n | §29 结构；三语 | T12 |
| T33 | Home/Markets/Asset/Watchlist/News 页 | §60 首屏验收；§61 步数验收 | T32,T14,T19 |
| T34 | 离线：缓存快照 + Offline 态 | AC-009 不白屏 | T33 |
| T35 | 登录 + 设置同步 | 与 Web 同账号数据一致 | T13,T33 |
| T36 | 移动端自动化（integration_test/Patrol 或 RN 对应） | 核心路径 CI 跑通 | T33 |

## Phase 5 — Alert & Push

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T37 | FCM/APNs + Notification Service | 触发→送达 P95<5s（AC-008） | T21 |
| T38 | in-app 通知中心 + notify_prefs | 告警落通知列表；偏好生效 | T37 |
| T39 | Web Notification | 浏览器推送可用 | T37 |

## Phase 6 — QA / Ops

| # | 任务 | 验收 | 依赖 |
|---|---|---|---|
| T40 | k6：1k API 并发 + 10k WS | error<1%、P95<500ms（§58） | T19,T22 |
| T41 | Failover：源失败 retry→alert→fallback | AC-010 | T05,T08 |
| T42 | Admin：数据源/资产/新闻/用户/告警监控（§46） | RBAC 保护；开关生效 | T13 |
| T43 | Terraform 全量 + CI/CD（§65）+ 备份/成本告警（§68/69） | staging→prod 流水线可跑 | 全部 |
