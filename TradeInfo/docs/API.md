# API.md — SimpleMarket

Contract-first：本文件是设计意图，**权威契约是 `backend/openapi.yaml`**（代码生成/校验用）。
Mock server 由 OpenAPI 生成（Prism 或同类），web/mobile/mock 三方共用（§70）。

## 1. 通用约定（§25.2）

- Base：`/api/v1`，版本在路径中
- Auth：`Authorization: Bearer <JWT>`；OAuth 登录后换发（短时效 access + refresh）
- 分页：`?cursor=<opaque>&limit=<n≤100>` → 响应 `{ "items": [], "next_cursor": "..." }`
- 错误：`{ "error": { "code": "ASSET_NOT_FOUND", "message": "..." } }`，HTTP status 语义正确
- Rate limit：`X-RateLimit-Limit` / `X-RateLimit-Remaining` / `X-RateLimit-Reset`，超限 429
- 所有时间 ISO8601 UTC；金额字段带 `currency`
- 行情响应统一带 `delay_minutes` 与 `quote_ts`，前端据此渲染 Live/Delayed（§18、AC-003）

## 2. 公开接口（无需登录）

| Method | Path | 说明 |
|---|---|---|
| GET | `/markets` | 市场总览（§7.2A 默认资产集），`?category=` |
| GET | `/markets/{category}` | indices/stocks/forex/crypto/commodities/bonds 表格（§8），`sort,country,exchange,cursor` |
| GET | `/assets/{asset_id}` | 详情头 + key data（§9） |
| GET | `/assets/{asset_id}/chart` | `?period=1D\|5D\|1M\|3M\|6M\|1Y\|5Y\|MAX` |
| GET | `/assets/{asset_id}/news` | 相关新闻 ≤5 默认（§9.3） |
| GET | `/search` | `?q=`，P95<500ms（AC-004），pg_trgm |
| GET | `/news` | `?category=top\|stocks\|forex\|crypto\|economy\|commodities`（§13） |
| GET | `/calendar` | `?from,to,country,importance,category`，默认 Today+High（§14、AC-007） |
| POST | `/auth/register` `/auth/login` `/auth/refresh` `/auth/oauth/{google,apple}` | §32 |

## 3. 用户接口（需登录）

| Method | Path | 说明 |
|---|---|---|
| GET/POST | `/watchlists` | 列表 / 创建（§11） |
| PATCH/DELETE | `/watchlists/{id}` | 改名 / 删除 |
| POST/DELETE | `/watchlists/{id}/items` | 加/删资产（AC-005 ≤1s） |
| PATCH | `/watchlists/{id}/items/reorder` | 排序 `{asset_ids: []}` |
| GET | `/portfolio` `/portfolio/positions` | 持仓与盈亏（§12） |
| POST/DELETE | `/portfolio/transactions` `/{tx_id}` | 流水录入 |
| GET/POST | `/alerts` | 列表 / 创建（§15 四种类型） |
| PATCH/DELETE | `/alerts/{id}` | 改条件 / 删除 |
| GET | `/notifications` | in-app 通知列表 |
| GET/PATCH | `/me/settings` | locale、color_mode、timezone、notify_prefs |
| POST/DELETE | `/me/devices` | push token 注册/注销 |

## 4. Admin（§46，独立 RBAC，略）

`/admin/...` 前缀，仅 `role=admin`。数据源开关、资产合并、新闻标记、用户管理。

## 5. WebSocket（§25.1）

`GET /ws/quotes`（鉴权可游客，限每连接订阅数）

```jsonc
// client → server
{ "type": "subscribe",   "symbols": ["stock_us_aapl", "crypto_btcusd"] }
{ "type": "unsubscribe", "symbols": ["stock_us_aapl"] }
{ "type": "pong" }

// server → client：连接后先 snapshot，之后 delta
{ "type": "snapshot", "data": [ { "asset_id": "...", "price": 250.10, "quote_ts": "...", "delay_minutes": 0 } ] }
{ "type": "quote",    "asset_id": "stock_us_aapl", "price": 250.15, "change": 2.36, "change_percent": 0.94, "quote_ts": "..." }
{ "type": "ping" }
{ "type": "error", "code": "SUBSCRIBE_LIMIT", "message": "..." }
```

- 心跳 30s；断线 client exponential backoff（1s→30s 上限），重连后重发 subscribe 重新收 snapshot
- Cloud Run 单连接 ~60min 上限：server 到期前发 `{ "type": "reconnect" }` 主动提示

## 6. 性能目标（§37）

P50<150ms / P95<500ms / P99<1000ms；`/markets`、`/assets/{id}`、`/chart` 走 Redis snapshot + CDN 缓存（ETag）。

## 7. Feature Flag（§47）

响应中的功能区块由 flag 控制：`crypto_enabled` `portfolio_enabled` `advanced_chart_enabled` `ai_summary_enabled`。客户端读 `GET /api/v1/flags`（公开、可缓存）。
