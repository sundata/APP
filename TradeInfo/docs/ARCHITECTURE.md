# ARCHITECTURE.md — SimpleMarket

依据 REQUIREMENTS §16–§22、§33、§52.1。技术选型见 `docs/adr/`。

## 1. 系统总览

```text
                    External Data Sources
                    (Licensed APIs / Official APIs / RSS)
                              │
                    ┌─────────▼──────────┐
                    │  Collectors        │  Cloud Run Jobs + Cloud Scheduler
                    │  (Python, §19)     │
                    └─────────┬──────────┘
                              │ raw payload + metadata
                    ┌─────────▼──────────┐
                    │  Cloud Storage     │  gs://market-data-raw/ (§20)
                    │  Raw Archive       │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Pub/Sub           │  topic: market-data-raw
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Data Processor    │  Cloud Run
                    │  normalize / validate / dedup / quarantine (§36)
                    └──────┬───────┬─────┬──────────┘
                           │       │     │
                     ┌─────▼──┐ ┌──▼───┐ ┌▼─────────┐
                     │ Redis  │ │Cloud │ │BigQuery  │
                     │(latest)│ │ SQL  │ │(history/ │
                     │        │ │  PG  │ │analytics)│
                     └───┬────┘ └──▲───┘ └──────────┘
                         │         │
              ┌──────────▼─────────┴──────────┐
              │  Backend API (FastAPI)        │  Cloud Run
              │  REST /api/v1 + WS /ws/quotes │
              └──────┬──────────────┬────────┘
                     │              │
               ┌─────▼─────┐  ┌─────▼──────┐
               │ Web       │  │ Mobile     │
               │ Next.js   │  │ Flutter    │
               └───────────┘  └────────────┘

        Alert Engine ──消费 quote stream──▶ Pub/Sub ──▶ Notification Service ──▶ FCM/APNs
```

## 2. 组件清单

| 组件 | 技术 | 部署 | 职责 |
|---|---|---|---|
| Web | Next.js + TS | Cloud Run / CDN | SSR/ISR，SEO，PWA（§27、§63） |
| Mobile | Flutter | App Store / Play | iOS + Android（§28） |
| Backend API | FastAPI | Cloud Run | REST + WS + Auth + Watchlist/Portfolio/Alert CRUD |
| Realtime fan-out | Redis Pub/Sub → WS | Memorystore + Cloud Run | snapshot→delta 推送（§25.1） |
| Collectors | Python (httpx/playwright) | Cloud Run Jobs + Scheduler | 按 `data_sources` 注册表采集 |
| Data Processor | Python | Cloud Run (Pub/Sub push) | 标准化、质量校验、去重、隔离 |
| Alert Engine | Python | Cloud Run | 评估 alert 条件 → 触发通知（§15.1） |
| Notification Service | Python | Cloud Run | FCM/APNs 投递，P95 < 5s（§33） |
| Admin | Next.js 独立路由或子应用 | Cloud Run | §46 后台管理，RBAC |

## 3. 数据存储分工（§22）

- **Cloud SQL PostgreSQL**：事务性数据（users/assets/watchlist/portfolio/alerts/news 元数据/日历/注册表），见 DATABASE.md
- **Memorystore Redis**：最新报价 `quote:{asset_id}`、market snapshot、session、WS fan-out channel、hot symbols
- **BigQuery**：tick 历史、新闻历史、行为分析、collector 指标。表必须按日期 partition + asset cluster，控制成本（§69）
- **Cloud Storage**：raw data 归档，lifecycle 规则（§20、§68）

## 4. 实时性分级（§18）

| Level | 延迟 | 适用 | 实现 |
|---|---|---|---|
| A Live | 1–5s | Crypto、有 streaming 授权的源 | WS fan-out |
| B Near RT | 5–30s | Stocks/Index/FX/Commodity | 轮询 collector + WS |
| C Fast | 30s–5m | News / Calendar / 公告 | collector → REST |
| D Periodic | 每日 | Fundamentals / 参考数据 | 定时 job |

UI 必须按来源 `delay_minutes` 展示 Live / Delayed / Updated Xs ago（§18、§39）。

## 5. 关键架构约束

1. **Web/App 不直连第三方源**（§16.1）——一切数据经后端。
2. **Cloud Run WS 限制**（§25.1）：单连接约 60 分钟上限 → client 到期自动重连；session affinity 开启；10,000 并发按实例并发数规划 min/max instances，压测不达标则拆独立 realtime 服务。
3. **合同先行**：OpenAPI spec 是唯一契约；web/mobile/mock 全部从它生成（§25.2、§70）。
4. **故障隔离**：单 collector/单源失败不得影响 API（§59、AC-010）；circuit breaker + quarantine。
5. **横向同步**：watchlist/alert/settings 存 PG，App/Web 读同一 API，天然一致（§2.1、AC-005）。

## 6. 环境（§64）

`local`（docker-compose）→ `dev` / `staging` / `production`（GCP 独立项目或独立 VPC+DB）。生产数据不进 dev。

## 7. 待决事项

- 行情 licensed vendor 选型（阻塞 Phase 1 真实数据接入，见 DATA_SOURCES.md）
- WS 规模超 Cloud Run 承载时的备选（GKE / 托管 WS 服务）——压测（§58）后定
