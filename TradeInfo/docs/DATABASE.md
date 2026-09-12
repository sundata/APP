# DATABASE.md — SimpleMarket

PostgreSQL 16（Cloud SQL）。Migration 用 Alembic，所有变更必须向后兼容（Cloud Run 滚动发布）。
所有时间戳 `timestamptz`，统一存 UTC；展示时按用户时区（`user_settings.timezone`）。

## 1. 表清单（REQUIREMENTS §23 扩展后）

| 表 | 用途 | 关键列 |
|---|---|---|
| `users` | 账号 | id, email (unique, citext), password_hash (nullable=仅 OAuth), display_name, status, created_at |
| `user_devices` | 推送设备 | id, user_id FK, platform(ios/android/web), push_token, last_seen_at |
| `exchanges` | 交易所 | exchange_id PK, mic, name, country, timezone, currency, trading_weekdays jsonb, sessions jsonb（本地时段 [["09:30","16:00"]]，支持午休） |
| `assets` | 统一资产主表（§24） | asset_id PK (`{type}_{country}_{symbol}` 规范), symbol, name, name_i18n jsonb, exchange_id FK, asset_type, country, currency, status |
| `asset_aliases` | 别名/多语言名 | id, asset_id FK, alias, alias_type(name/symbol), locale, source_id（逻辑引用 data_sources） |
| `asset_identifiers` | 结构化标识 | asset_id FK, scheme(isin/figi/source:{id}), value, UNIQUE(scheme,value) |
| `market_quotes` | 最新报价持久层（重启恢复用） | asset_id PK, price, change, change_pct, day_high, day_low, volume, quote_ts, source_id, delay_minutes |
| `quote_quarantine` | 校验拒绝的行情（§36，仅审计/重放，不展示） | id, asset_id（无 FK）, source_id FK, reason, payload jsonb, quote_ts, created_at |
| `price_history` | 日线 OHLCV | asset_id, date, open, high, low, close, volume, UNIQUE(asset_id,date) |
| `watchlists` | 自选清单 | id, user_id FK, name, position, created_at |
| `watchlist_items` | 自选项（≤200/list §11） | id, watchlist_id FK, asset_id FK, position, added_at, UNIQUE(watchlist_id,asset_id) |
| `portfolios` | 组合 | id, user_id FK, name, base_currency, created_at |
| `portfolio_transactions` | 流水（§12） | id, portfolio_id FK, asset_id FK, side(buy/sell), quantity, price, currency, fee, traded_at |
| `portfolio_positions` | 持仓物化（由流水重算） | portfolio_id, asset_id, quantity, avg_cost, realized_pl, UNIQUE(portfolio_id,asset_id) |
| `alerts` | 告警（§15） | id, user_id FK, asset_id FK nullable, alert_type(price/change_pct/daily_change/event), condition jsonb, mode(one_shot/recurring), cooldown_sec, enabled, last_triggered_at |
| `alert_trigger_log` | 触发记录（§15.1 去重） | id, alert_id FK, triggered_at, trigger_value, notification_id |
| `notifications` | 通知 | id, user_id FK, type, title, body, payload jsonb, sent_at, read_at |
| `news` | 新闻元数据（§13，不存全文） | id, title, summary, source, source_url, published_at, language, importance_score, content_hash, dedup_group_id |
| `news_asset_relations` | 新闻↔资产 | news_id FK, asset_id FK |
| `economic_events` | 财经日历（§14） | id, country, currency, event_name, event_time_utc, importance, actual, forecast, previous, source_id |
| `market_calendars` | 开闭市/假日（§39 freshness 依赖） | exchange_id FK, date, open_utc, close_utc, is_holiday, UNIQUE(exchange_id,date) |
| `data_sources` | 数据源注册表（§17 字段全保留） | source_id PK, source_name, base_url, data_type, collection_type, license_status, robots_status, terms_reviewed, refresh_interval, delay_minutes, priority, enabled, last_success_at, last_error |
| `collector_jobs` | 采集任务记录 | id, source_id FK, collector_type, started_at, finished_at, status, items_count |
| `collector_errors` | 采集错误 | id, job_id FK, source_id, error_type, message, created_at |
| `feature_flags` | 功能开关（§47） | key PK, enabled, rollout jsonb, description |
| `user_settings` | 用户设置 | user_id PK FK, locale, market_color_mode(western/asian §30.3), timezone, base_currency, notify_prefs jsonb |
| `fx_rates` | 汇率（Portfolio 基准换算 Phase 1.5+） | base, quote, rate, asof, source_id, UNIQUE(base,quote,asof) |

## 2. 索引要点

- `assets(symbol)`、`asset_aliases(lower(alias), locale)` —— 支撑 §10 搜索 + `pg_trgm` 索引（`CREATE EXTENSION pg_trgm`）
- `market_quotes.asset_id` PK；Redis 是读路径，PG 表仅作持久副本
- `news(published_at desc)`、`news(dedup_group_id)`、`news(content_hash)`
- `economic_events(event_time_utc)`、`(country, importance)`
- `alerts(user_id)`、`alerts(enabled, alert_type)` —— Alert Engine 扫描用
- `watchlist_items(watchlist_id, position)`

## 3. Redis 键设计（Memorystore）

```text
quote:{asset_id}            HASH   price/change/ts/delay_minutes   TTL=无（覆盖写）
snapshot:{scope}            STRING JSON 首页/市场页快照              TTL=30s
ws:fanout:{asset_id}        PUBSUB channel                          WS 推送
session:{token}             STRING                                  会话
ratelimit:{key}             STRING+TTL                              限流
hot:symbols                 ZSET                                    热门资产
```

## 4. BigQuery

```text
market_ticks      (asset_id, price, ts, source_id)   PARTITION ts DATE, CLUSTER asset_id
news_history      (news 全字段 + fetched_at)          PARTITION published_at
analytics_events  (user_id, event, payload, ts)       PARTITION ts（§48）
collector_metrics (job 指标历史)                      PARTITION started_at
```

所有表日期分区 + 聚簇，配合 §69 的 BigQuery quota。

## 5. 数据质量与隔离（§36）

`market_quotes`/`price_history` 只写校验后数据；异常数据进 `quarantine_raw`（或仅留 Storage raw + `collector_errors` 标记），不进展示路径。

## 6. 备份（§68）

Cloud SQL：每日自动备份 + PITR。Storage raw：lifecycle 规则（如 90 天转 Nearline，1 年删，按合规评估调）。
