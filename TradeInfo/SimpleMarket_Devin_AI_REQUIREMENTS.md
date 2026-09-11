# SimpleMarket Platform — Devin AI 开发要求式样书

> Version: 0.1  
> Target: Web Site + Mobile App (iOS / Android)  
> Reference Product: Investing.com  
> Primary Goal: 在保留“行情、新闻、财经日历、自选、提醒”等核心价值的前提下，做一个**内容更简要、操作更直接、加载更快、信息层级更清晰**的金融信息平台。  
> Cloud: Google Cloud Platform (GCP)  
> Development Executor: Devin AI

---

# 1. 项目目标

开发一个面向普通投资者和中轻度交易用户的全球金融信息平台，包括：

1. Web Site
2. iOS App
3. Android App
4. Backend API
5. 数据采集 / 数据清洗 / 数据存储系统
6. 实时行情更新系统
7. 新闻与财经事件系统
8. Watchlist / Portfolio / Alert 用户功能
9. 后台管理系统

本项目**不是交易平台**。

第一阶段只提供：

- 金融信息查看
- 自选资产
- 行情监控
- 新闻
- 财经日历
- 价格提醒
- 简单投资组合记录

暂不提供：

- 股票买卖
- 经纪商交易接入
- 自动交易
- 投资建议
- 跟单
- 用户资金托管

---

# 2. 产品定位

## 2.1 核心原则

产品设计必须遵循：

**Simple → Fast → Useful → Real-time**

即：

- 页面不要堆过多模块
- 首页 3 秒内让用户看到重要市场变化
- 常用功能最多 1～2 次点击到达
- 默认只显示用户最需要的信息
- 复杂数据通过二级页面展开
- 新闻不能挤占行情主要区域
- 广告不能破坏主流程
- App 与 Site 数据一致
- 同一账号的自选、提醒、设置实时同步

---

# 3. 与 Investing.com 的主要区别

参考 Investing.com 的功能体系，但不要复制其 UI、图标、文字、页面结构或受版权保护内容。

核心差异：

| 项目 | 参考平台常见方式 | 本平台要求 |
|---|---|---|
| 首页 | 信息量非常大 | 简洁 Dashboard |
| 行情 | 多层菜单 | 首页直接看主要资产 |
| 新闻 | 数量多 | 只显示重要新闻 |
| 自选 | 功能丰富但较复杂 | 一屏完成主要操作 |
| 图表 | 专业指标多 | 默认简单，专业模式可展开 |
| 财经日历 | 信息很多 | 默认只显示高影响事件 |
| Portfolio | 新闻/数据混杂 | 默认只看资产和盈亏 |
| App 操作 | 功能全面 | 减少层级 |
| 用户学习成本 | 中高 | 低 |
| 数据展示 | 尽量多 | 尽量有效 |

---

# 4. 支持的金融资产

MVP 支持：

- 股票 Stock
- ETF
- 指数 Index
- 外汇 Forex
- 加密货币 Crypto
- 商品 Commodity
- 国债收益率 / Bond Yield

后续扩展：

- Mutual Fund
- Futures
- Options
- Bonds
- Interest Rate
- CFD

---

# 5. MVP 目标市场

第一阶段重点覆盖：

1. 美国
2. 日本
3. 澳大利亚
4. 中国 / 香港
5. 欧洲主要市场
6. 全球主要指数
7. 全球主要 Forex
8. BTC / ETH 等主要 Crypto

主要交易所：

- NYSE
- NASDAQ
- AMEX
- TSE / JPX
- ASX
- HKEX
- SSE
- SZSE
- LSE
- Euronext

---

# 6. 页面结构

## 6.1 Web Site 一级导航

Desktop：

- Markets
- Watchlist
- News
- Calendar
- Portfolio
- Search

右侧：

- Alert
- Language
- Login / User

Mobile Web：

底部固定导航：

- Home
- Markets
- Watchlist
- News
- Me

---

# 7. 首页 Home

## 7.1 首页目标

用户进入平台 3 秒内知道：

- 今天市场整体涨还是跌
- 自己关注的资产怎么样
- 有没有重要财经事件
- 有没有重大新闻

首页不能设计成新闻门户。

---

## 7.2 首页结构

### A. Global Market Summary

默认显示：

- S&P 500
- NASDAQ
- Dow Jones
- Nikkei 225
- ASX 200
- Hang Seng
- Shanghai Composite
- Gold
- WTI Oil
- BTC
- USD/JPY
- AUD/USD

每项显示：

- Name
- Symbol
- Last Price
- Change
- Change %
- Market Status

点击进入详情。

---

### B. My Watchlist

未登录：

显示：

`Add your first asset`

登录：

显示前 5～10 个自选。

字段：

- Symbol
- Name
- Price
- %
- Mini Sparkline

---

### C. Important Events Today

默认：

只显示 High Impact。

例如：

- Fed Rate Decision
- CPI
- GDP
- Employment
- RBA
- BOJ
- ECB

字段：

- Time
- Country
- Event
- Importance
- Actual
- Forecast
- Previous

---

### D. Important News

最多显示 5 条。

优先：

1. Breaking
2. 用户 Watchlist 相关
3. 高市场影响
4. 全球重大财经新闻

字段：

- Time
- Headline
- Source
- Related Assets

首页不要显示长摘要。

---

# 8. Markets 页面

一级分类：

- Indices
- Stocks
- Forex
- Crypto
- Commodities
- Bonds

每页默认 Table。

字段：

- Name
- Symbol
- Last
- Change
- Change %
- Day High
- Day Low
- Time

支持：

- Sort
- Search
- Country Filter
- Exchange Filter
- Favorite

---

# 9. Asset Detail 页面

例如 AAPL。

页面顶部：

- Apple Inc.
- AAPL
- Exchange
- Market status
- Last price
- Price change
- %

---

## 9.1 Chart

默认：

Line Chart

周期：

- 1D
- 5D
- 1M
- 3M
- 6M
- 1Y
- 5Y
- MAX

第二阶段：

- Candlestick
- Technical Indicators

MVP 不需要 100+ 指标。

---

## 9.2 Key Data

股票：

- Open
- Previous Close
- Day Range
- 52W Range
- Volume
- Market Cap
- P/E
- EPS
- Dividend Yield
- Earnings Date

Crypto / FX 等根据类型显示对应字段。

---

## 9.3 Related News

最多默认 5 条。

只显示：

- Headline
- Time
- Source

点击展开。

---

# 10. Search

顶部全局搜索。

输入：

`Apple`

返回：

Apple Inc.  
AAPL  
NASDAQ

输入：

`7203`

返回：

Toyota Motor  
7203  
TSE

支持：

- Name
- Symbol
- ISIN（后期）
- Exchange
- Crypto pair

目标：

P95 搜索结果 < 500 ms。

---

# 11. Watchlist

用户可以：

- Add
- Remove
- Reorder
- Create List

默认 List：

`My Watchlist`

可以创建：

- US Stocks
- Japan
- Crypto
- Long Term
- Trading

每个 List 最多：

MVP 200 instruments。

---

# 12. Portfolio

Portfolio 必须保持简单。

用户输入：

- Asset
- Buy / Sell
- Quantity
- Price
- Date
- Fee
- Currency

自动计算：

- Holdings
- Average Cost
- Market Value
- Unrealized P/L
- Realized P/L
- Daily P/L

Portfolio 首页不要自动混入大量新闻。

---

# 13. News

分类：

- Top
- Stocks
- Forex
- Crypto
- Economy
- Commodities

新闻来源：

- 官方机构
- 交易所
- 公司公告
- 财经媒体
- RSS
- 经合法授权的数据源
- 可抓取公开页面

新闻统一格式：

```json
{
  "id": "",
  "title": "",
  "summary": "",
  "source": "",
  "source_url": "",
  "published_at": "",
  "language": "",
  "related_symbols": [],
  "category": [],
  "importance_score": 0
}
```

---

# 14. Economic Calendar

字段：

```text
country
currency
event_name
event_time
importance
actual
forecast
previous
source
```

过滤：

- Today
- Tomorrow
- This Week
- Country
- Importance
- Category

默认：

`Today + High Impact`

---

# 15. Price Alert

用户可设置：

### Price

AAPL > 250 USD

### Change %

AAPL +5%

### Daily Change

NASDAQ < -2%

### Economic Event

US CPI Released

通知方式：

MVP：

- App Push
- Web Notification
- In-App Notification

第二阶段：

- Email
- LINE
- Telegram

---

# 16. 数据采集架构

## 16.1 原则

不要让 Web / App 直接访问第三方网站。

正确流程：

```text
External Data Sources
        ↓
Crawler / API Collector
        ↓
Raw Data
        ↓
Normalize / Validate / Deduplicate
        ↓
Google Cloud Storage / Database
        ↓
Backend API
        ↓
Web / App
```

---

# 17. 数据源策略

数据来源优先级：

1. Official API
2. Exchange / Government API
3. Licensed Data Provider
4. RSS
5. Public Web Page Crawler

Crawler 只能用于：

- 法律允许
- 网站条款允许
- robots.txt 允许
- 不需要绕过登录、验证码或技术访问控制
- 不采集个人敏感数据
- 不复制禁止转载的完整版权内容

不得因为“技术上可以爬取”就直接上线。

开发时必须维护：

`data_source_registry`

字段：

```text
source_id
source_name
base_url
data_type
collection_type
license_status
robots_status
terms_reviewed
refresh_interval
priority
enabled
last_success_at
last_error
```

---

# 18. 实时性定义

不能把所有数据统一称为 Real-time。

定义：

### Level A — Live

目标：

1～5 秒更新。

适用：

- Crypto
- 可获得 streaming API 的市场行情

---

### Level B — Near Real-Time

目标：

5～30 秒。

适用：

- Stocks
- Index
- FX
- Commodity

具体延迟取决于数据许可。

必须在 UI 显示：

- Live
- Delayed 15m
- Updated 10 sec ago

---

### Level C — Fast Update

30 秒～5 分钟。

适用：

- News
- Calendar Update
- Company announcement

---

### Level D — Periodic

每日或周期更新。

适用：

- Fundamentals
- Financial Statements
- PE
- EPS
- Market Cap reference data

---

# 19. Crawler 要求

Crawler 独立部署。

建议：

- Python
- Scrapy / Playwright
- Cloud Run
- Cloud Scheduler
- Pub/Sub

Crawler 类型：

```text
MarketCollector
NewsCollector
CalendarCollector
FundamentalCollector
ReferenceCollector
```

---

## 19.1 Crawler 必须具备

- Retry
- Timeout
- Rate Limit
- User Agent
- Proxy optional
- Circuit Breaker
- HTML schema change detection
- Error logging
- Monitoring
- Duplicate detection
- Source priority
- Backoff

不要通过 CAPTCHA bypass 或反爬绕过实现数据采集。

---

# 20. Raw Data 保存

原始采集数据必须保留。

Google Cloud Storage：

```text
gs://market-data-raw/
    /market/
        /source/
            /YYYY/MM/DD/HH/
    /news/
    /calendar/
    /fundamental/
```

文件：

JSON / JSONL / Parquet。

Raw data 必须包含：

```json
{
  "source": "",
  "source_url": "",
  "fetched_at": "",
  "content_hash": "",
  "payload": {}
}
```

用途：

- Debug
- Data replay
- Audit
- Reprocessing

---

# 21. Google Cloud 架构

建议 MVP：

```text
Cloud DNS
    ↓
Cloud CDN
    ↓
Load Balancer
    ↓
Cloud Run
    ↓
Backend API
    ↓
Cloud SQL PostgreSQL
       +
Memorystore Redis
       +
BigQuery
       +
Cloud Storage
```

Event：

```text
Collectors
    ↓
Pub/Sub
    ↓
Data Processor
    ↓
Redis / PostgreSQL / BigQuery
```

---

# 22. Database

## PostgreSQL

用于：

- users
- assets
- exchanges
- watchlists
- portfolio
- alerts
- news metadata
- calendar
- notification

---

## Redis

用于：

- Last Price
- Market Snapshot
- Hot Symbols
- Cache
- User session
- Realtime fan-out

---

## BigQuery

用于：

- Tick / Price History
- Analytics
- News history
- User behavior analytics
- Monitoring history

---

# 23. 核心数据库表

最低需要：

```text
users
user_devices
assets
exchanges
asset_aliases
market_quotes
price_history
watchlists
watchlist_items
portfolios
portfolio_transactions
portfolio_positions
alerts
notifications
news
news_asset_relations
economic_events
data_sources
collector_jobs
collector_errors
```

---

# 24. Asset Master

所有来源的数据必须映射到统一 Asset ID。

例如：

```json
{
  "asset_id": "stock_us_aapl",
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "exchange": "NASDAQ",
  "currency": "USD",
  "asset_type": "stock",
  "country": "US"
}
```

不同来源：

`Apple`
`AAPL`
`NASDAQ:AAPL`

必须最终统一到：

`stock_us_aapl`

---

# 25. API

建议：

REST + WebSocket。

REST：

```text
GET /api/v1/markets
GET /api/v1/assets/{id}
GET /api/v1/assets/{id}/chart
GET /api/v1/assets/{id}/news
GET /api/v1/search
GET /api/v1/news
GET /api/v1/calendar

GET /api/v1/watchlists
POST /api/v1/watchlists
POST /api/v1/watchlists/{id}/items

GET /api/v1/portfolio
POST /api/v1/portfolio/transactions

GET /api/v1/alerts
POST /api/v1/alerts
DELETE /api/v1/alerts/{id}
```

WebSocket：

```text
/ws/quotes
```

Client subscribe：

```json
{
  "type": "subscribe",
  "symbols": ["AAPL", "NVDA", "BTCUSD"]
}
```

Server：

```json
{
  "symbol": "AAPL",
  "price": 250.10,
  "change": 2.31,
  "change_percent": 0.93,
  "timestamp": "..."
}
```

---

# 26. Backend

推荐：

Python FastAPI

或：

TypeScript NestJS

优先要求：

- Async
- OpenAPI
- Unit Test
- Integration Test
- WebSocket
- Redis
- PostgreSQL

---

# 27. Web Frontend

推荐：

Next.js + TypeScript

要求：

- Responsive
- PWA compatible
- SEO
- SSR / ISR where appropriate
- WebSocket
- Dark Mode
- i18n

---

# 28. Mobile App

建议：

Flutter

原因：

- iOS / Android 共用代码
- UI 一致
- 开发速度快
- WebSocket 支持良好

也可以：

React Native。

Devin 必须在开始开发前记录最终选择理由。

---

# 29. App 页面

底部 5 Tab：

```text
Home
Markets
Watchlist
News
Me
```

Search：

Home 顶部。

Calendar：

Home 快捷入口 + Markets / More。

Portfolio：

Me 或 Watchlist 顶部入口。

---

# 30. UI / UX 要求

## 30.1 设计关键词

- Minimal
- Clean
- Financial
- Professional
- Fast
- Mobile First

---

## 30.2 信息密度

禁止：

- 首页 20+ 模块
- 大量 banner
- 自动播放视频
- 页面打开自动弹多个 popup
- 新闻覆盖行情
- 同一页显示过多指标

---

## 30.3 色彩

默认：

涨：

Green

跌：

Red

必须支持：

`Asian Mode`

涨：

Red

跌：

Green

用户可选择。

---

# 31. 多语言

MVP：

- English
- Japanese
- Simplified Chinese

第二阶段：

- Traditional Chinese
- Korean
- German
- French

所有文本必须走 i18n。

禁止 hardcoded UI text。

---

# 32. 账号

支持：

- Email
- Google
- Apple

用户数据：

- Watchlist
- Portfolio
- Alert
- Settings

必须跨 Web / App 同步。

---

# 33. Push Notification

建议：

Firebase Cloud Messaging。

触发：

```text
Alert Engine
    ↓
Pub/Sub
    ↓
Notification Service
    ↓
FCM / APNs
```

目标：

条件触发后：

P95 < 5 sec

不包括第三方行情源本身延迟。

---

# 34. News Ranking

不要纯粹按照发布时间。

建议：

```text
score =
breaking_weight
+ source_weight
+ market_impact
+ watchlist_relation
+ freshness
```

例如：

```text
Breaking News     +50
High Trust Source +20
Watchlist Match   +20
< 30 min          +15
High Market Impact +20
```

---

# 35. 数据去重

同一新闻来自多个来源时：

根据：

- normalized title
- URL
- content hash
- semantic similarity

聚合。

前端可以：

```text
Fed keeps rates unchanged
Reuters + 5 sources
```

不要显示 6 条相同新闻。

---

# 36. Data Quality

行情进入系统前必须验证：

- symbol exists
- timestamp valid
- currency valid
- price > 0
- impossible jump detection
- stale data detection
- duplicate tick
- market status

异常数据：

进入 quarantine。

不能直接显示。

---

# 37. 系统性能要求

## API

目标：

P50 < 150 ms  
P95 < 500 ms  
P99 < 1000 ms

Search：

P95 < 500 ms

---

## Homepage

Web：

Largest Contentful Paint < 2.5 sec

Mobile：

首次主要内容：

< 2.5 sec（正常 4G / 5G）

---

# 38. 可用性

目标：

MVP：

99.9%

---

# 39. 数据新鲜度

必须实现：

`data_freshness_monitor`

示例：

```text
AAPL last update: 4 sec
BTCUSD last update: 1 sec
Nikkei: 16 min delay
```

如果超过阈值：

- UI 显示 delayed
- 后台告警

禁止把 stale data 当 live。

---

# 40. Monitoring

Google Cloud Monitoring。

必须监控：

- API error
- API latency
- crawler success rate
- source failure
- WebSocket connection
- Redis
- DB
- CPU
- Memory
- Pub/Sub backlog
- Data freshness

---

# 41. Logging

所有服务 JSON log。

字段：

```json
{
  "timestamp": "",
  "service": "",
  "environment": "",
  "request_id": "",
  "user_id": "",
  "source_id": "",
  "level": "",
  "message": ""
}
```

敏感信息禁止直接写入日志。

---

# 42. Security

最低要求：

- HTTPS only
- TLS 1.2+
- JWT / secure session
- OAuth 2.0
- Rate Limiting
- WAF
- Secret Manager
- IAM least privilege
- DB private access
- Encryption at rest
- Encryption in transit

---

# 43. Privacy

不保存：

- 用户银行卡
- Broker 密码
- Trading account credential

Portfolio 是用户手动记录的数据。

Privacy Policy 必须说明：

- 收集什么
- 为什么
- 保存多久
- 如何删除账号

---

# 44. 法务要求

开发时必须建立：

```text
DATA_SOURCE_COMPLIANCE.md
```

每个来源记录：

- Terms of Service
- API terms
- Robots
- Copyright
- Redistribute permission
- Commercial use
- Attribution requirement
- Delay requirement
- Market data licensing

特别注意：

“可访问网页”不等于“允许商业再发布数据”。

---

# 45. 财务信息 Disclaimer

所有页面底部：

```text
Information provided by this platform is for informational purposes only
and does not constitute investment advice.

Market data may be delayed depending on the exchange and data provider.
```

中文、日文必须对应显示。

---

# 46. Admin System

后台功能：

### Data Sources

- Enable
- Disable
- Last Fetch
- Error
- Success Rate

### Assets

- Search
- Merge
- Correct Symbol
- Disable

### News

- Remove
- Mark Breaking
- Edit Category

### Calendar

- Edit
- Correct

### Users

- Status
- Ban
- Delete

### Alert

- Monitoring

---

# 47. Feature Flag

必须支持 Feature Flag。

例如：

```text
crypto_enabled
portfolio_enabled
advanced_chart_enabled
ai_summary_enabled
```

便于分阶段上线。

---

# 48. Analytics

记录：

- DAU
- MAU
- Session
- Search
- Add Watchlist
- Alert Created
- News Click
- Asset Viewed

重点指标：

```text
Watchlist Adoption
Daily Active Watchlist Users
Alert Usage
Search Success Rate
Retention D1 / D7 / D30
```

---

# 49. MVP 范围

必须完成：

### Platform

- Web
- iOS
- Android

### Market

- Index
- Stock
- Forex
- Crypto
- Commodity

### Feature

- Home
- Markets
- Asset Detail
- Chart
- Search
- Watchlist
- News
- Calendar
- Price Alert
- Login
- Push Notification

Portfolio 可以：

MVP Phase 1.5。

---

# 50. MVP 不做

MVP 禁止主动扩张到：

- Trading
- Broker integration
- AI stock prediction
- Social community
- Chat
- Copy trading
- Options strategy
- 100+ technical indicator
- Complex screener
- Premium subscription
- Advertising engine

先把核心体验做稳定。

---

# 51. 开发阶段

## Phase 0 — Architecture

输出：

```text
ARCHITECTURE.md
DATABASE.md
API.md
DATA_SOURCE_COMPLIANCE.md
DEPLOYMENT.md
```

完成后才能进入开发。

---

## Phase 1 — Data

完成：

- Asset Master
- Data source registry
- Market collector
- News collector
- Calendar collector
- Storage
- Data normalize
- Redis
- PostgreSQL

---

## Phase 2 — Backend

完成：

- REST API
- Search
- WebSocket
- Watchlist
- User
- Alert

---

## Phase 3 — Web

完成：

- Home
- Market
- Detail
- Search
- Watchlist
- News
- Calendar

---

## Phase 4 — App

iOS / Android。

---

## Phase 5 — Alert

Push。

---

## Phase 6 — QA

Load test。

Failover test。

Crawler failure test。

---

# 52. Devin AI 工作要求

Devin 不允许一次性写完整系统后再测试。

必须循环：

```text
Plan
↓
Implement
↓
Test
↓
Run
↓
Validate
↓
Commit
```

---

# 53. Git 要求

Branch：

```text
main
develop
feature/*
fix/*
```

Commit：

清晰说明。

例如：

```text
feat: add realtime quote websocket
fix: prevent duplicate news records
```

---

# 54. Test 要求

Backend：

Unit Test ≥ 80% core service coverage。

必须包含：

- API
- Auth
- Watchlist
- Alert
- Data normalize
- Duplicate news
- Crawler parser

---

# 55. E2E Test

必须使用：

Playwright。

测试：

```text
Open Home
Search AAPL
Open AAPL
Add Watchlist
Set Alert
Open News
Open Calendar
Login
Logout
```

---

# 56. Mobile Test

至少：

iPhone：

- iPhone 15+
- latest iOS + previous major version

Android：

- Pixel class
- Samsung class
- latest Android + previous 2 major versions

---

# 57. 验收条件 Acceptance Criteria

## AC-001 Home

Given 用户打开首页  
When 数据正常  
Then 2.5 秒内显示主要 Market Summary。

---

## AC-002 Real-time

Given 用户打开 AAPL  
When 后端收到新行情  
Then 页面不刷新浏览器的情况下自动更新价格。

---

## AC-003 Freshness

Given 行情超过允许延迟  
Then UI 必须显示：

`Delayed`

不得显示：

`Live`

---

## AC-004 Search

输入：

`AAPL`

500ms P95 内出现 Apple。

---

## AC-005 Watchlist

用户点击 Star。

必须：

1 秒内加入。

Web 登录后 App 必须同步。

---

## AC-006 News

同一新闻多来源。

前端不得连续显示明显重复新闻。

---

## AC-007 Calendar

默认只显示：

Today + High Impact。

用户可以修改。

---

## AC-008 Alert

设置：

AAPL > X。

价格满足时：

Push Notification。

从系统收到满足条件行情开始计算：

P95 ≤ 5 秒。

---

## AC-009 App Offline

网络断开：

显示：

- Last cached data
- Offline

不能白屏。

---

## AC-010 Data Source Failure

如果 Source A 失败：

必须：

- retry
- log
- monitoring alert

如果有 Source B：

可以自动 fallback。

---

# 58. Performance Validation

使用 k6。

最低测试：

```text
1,000 concurrent API users
10,000 WebSocket connections
```

目标：

error rate < 1%

P95 API < 500ms。

生产规模扩大前重新测试。

---

# 59. Crawler Validation

每个 Crawler 必须：

```text
Parser Test
Schema Test
Data Quality Test
Duplicate Test
Timeout Test
Source Failure Test
```

HTML 结构改变：

不能导致整个 collector crash。

---

# 60. UI 验收

首页手机端：

在第一次滚动前至少看到：

- Market Summary
- Watchlist summary
- Important Events / News 中一个

禁止首屏主要位置被：

- 广告
- 新闻长文
- Promotion

占用。

---

# 61. App 操作验收

核心操作：

### Add Watchlist

≤ 2 taps

### Search Asset

≤ 2 taps

### Set Price Alert

≤ 3 taps

### View Chart

≤ 2 taps

---

# 62. Accessibility

最低：

WCAG 2.1 AA。

要求：

- Font scaling
- Screen reader
- Keyboard Web navigation
- Contrast
- Button touch target

---

# 63. SEO

Web Asset Page：

例如：

```text
/markets/stocks/us/aapl
```

必须：

- SSR
- Meta
- OpenGraph
- Structured Data
- Canonical URL

News：

SEO indexable。

用户页面：

noindex。

---

# 64. Environment

```text
local
dev
staging
production
```

Production 数据不得直接用于 dev。

---

# 65. CI/CD

GitHub Actions。

流程：

```text
Lint
Test
Build
Security Scan
Deploy Staging
E2E
Manual / Automated Gate
Deploy Production
```

---

# 66. Infrastructure as Code

Terraform。

GCP 资源：

必须通过 Terraform 管理。

---

# 67. Secret

禁止：

`.env production`

提交 Git。

使用：

Google Secret Manager。

---

# 68. Backup

PostgreSQL：

Daily Backup。

PITR：

启用。

Raw market data：

Cloud Storage lifecycle。

---

# 69. Cost Control

GCP 必须设置：

- Budget
- Alert
- BigQuery quota
- Logging retention
- Storage lifecycle

开发环境夜间允许 scale to zero。

---

# 70. 第一版 UI 原型

Devin 首先制作：

```text
/home
/markets
/asset
/watchlist
/news
/calendar
/login
```

使用 Mock API。

UI 通过后再接真实数据。

---

# 71. 示例首页

Desktop：

```text
----------------------------------------------------
Logo        Search                       Alert User
----------------------------------------------------

Markets
S&P500    NASDAQ    Nikkei    Gold    BTC
+0.4%     +0.8%     -0.2%     +1.1%  +2.3%

My Watchlist
AAPL       250.10     +0.93%
NVDA       180.20     +1.20%
7203       3,250      -0.40%

Important Today
14:30 US CPI          HIGH
22:00 Fed Chair       HIGH

Top News
10:31 Fed...
09:50 Apple...
----------------------------------------------------
```

---

# 72. 手机首页

```text
-----------------------
Search
-----------------------

Market
S&P500      +0.4%
NASDAQ      +0.8%
Nikkei      -0.2%
BTC         +2.3%

Watchlist
AAPL        +0.9%
NVDA        +1.2%

Today
US CPI      14:30

News
Fed...
Apple...

-----------------------
Home Markets Watch News Me
-----------------------
```

---

# 73. 成功标准

MVP 成功的判断不是“功能比 Investing.com 多”。

成功标准：

> 用户可以在 30 秒内完成：
>
> 1. 看今天市场
> 2. 找到一只股票
> 3. 加到自选
> 4. 看图表
> 5. 设价格提醒
>
> 不需要教程。

---

# 74. 最重要的产品原则

如果一个功能不能明显回答以下任意一个问题：

```text
市场现在怎么样？
我关注的资产怎么样？
今天有什么重要事件？
有什么重要消息？
什么时候需要提醒我？
```

则不应该进入首页。

---

# 75. Devin AI 开始执行时的首个 Prompt

```text
Read REQUIREMENTS.md completely.

Do not start coding immediately.

First create:

1. ARCHITECTURE.md
2. DATABASE.md
3. API.md
4. DATA_SOURCES.md
5. DATA_SOURCE_COMPLIANCE.md
6. DEVELOPMENT_PLAN.md
7. MVP_TASKS.md

The product is a simplified real-time financial market information
platform inspired by the functional scope of Investing.com, but it must
have an original UI/UX and a substantially simpler information hierarchy.

The platform consists of:

- Responsive Web Site
- iOS App
- Android App
- Backend API
- Realtime quote service
- Market/news/calendar collectors
- Google Cloud data/storage infrastructure
- User watchlists and price alerts

Important priorities:

1. Simplicity
2. Data correctness
3. Clear freshness/delay labels
4. Fast UX
5. Reliable collection architecture
6. Legal/licensing compliance for every data source
7. Shared account state across Web and Mobile

Do not scrape or reproduce third-party content in violation of Terms of
Service, robots.txt, copyright, access controls, data licensing, or
redistribution restrictions.

After generating the seven planning files, review them for conflicts and
missing dependencies. Then create the implementation plan as small,
testable milestones.

Do not implement trading, broker integration, social features, AI stock
prediction, or other out-of-scope functionality unless REQUIREMENTS.md
is explicitly updated.
```

---

# 76. Definition of Done

MVP 才能称为 Done，当且仅当：

- Web 可正常使用
- iOS 可正常使用
- Android 可正常使用
- 实时 / 延迟状态明确
- Watchlist 跨设备同步
- Price Alert 可实际触发
- News 可正常采集 / 去重
- Calendar 正常
- Source failure 有监控
- API 有测试
- E2E 通过
- Production GCP 可部署
- Backup 正常
- Data source compliance 有记录
- 无 Critical / High security issue
- 主要操作符合点击次数要求
- 所有关键页面都有 Loading / Empty / Error / Offline 状态

---

# 77. 后续 Phase 2 候选功能

MVP 稳定以后再考虑：

- Portfolio Advanced
- Earnings Calendar
- Stock Screener
- Financial Statements
- Technical Indicators
- AI News Summary
- AI Asset Summary
- Personalized Market Brief
- Email Daily Brief
- Multi-device Alert Center
- Advanced Charts
- Premium Plan

---

# 78. 最终原则

**不要做“另一个更复杂的 Investing.com”。**

目标是：

> 用 Investing.com 约 20%～30% 的核心功能，
> 满足普通用户 80%～90% 的日常金融市场信息需求。

每次新增功能前，必须先回答：

1. 用户是否高频使用？
2. 是否能减少用户操作？
3. 是否能提高信息判断效率？
4. 是否值得增加 UI 复杂度？
5. 数据是否有合法、稳定、可持续的来源？

如果不能明确回答，暂不开发。
