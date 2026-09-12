# DEVELOPMENT_PLAN.md — SimpleMarket

按 REQUIREMENTS §51 阶段划分，允许并行流。任务粒度见 MVP_TASKS.md。

## 阶段总览

```text
Phase 0  规划（本批文档）         ── 已完成
Phase 1  Data（asset master / collectors / normalize / storage）
Phase 2  Backend（REST / search / WS / auth / watchlist / alert engine）
Phase 3  Web（§70 mock 原型 → 接真实数据）
Phase 4  Mobile（iOS / Android）
Phase 5  Alert & Push（FCM/APNs 端到端）
Phase 6  QA（k6 压测 / failover / crawler failure）
```

## 并行流（比 §51 的纯串行更高效）

- **UI 原型流**：Phase 1 一开始即可并行——OpenAPI spec 先冻结（API.md），mock server（Prism）自动生成，Web 按 §70 先用 mock 开发。不阻塞真实数据。
- **Infra 流**：Terraform 骨架（Cloud SQL/Redis/PubSub/Storage/Cloud Run）从 Phase 1 并行推进。
- **移动端**在 Phase 4 前只需同一套 API + WebSocket，架构上无额外依赖。

## 各阶段退出条件

### Phase 1 — Data
- [ ] `assets`/`exchanges`/`asset_aliases`/`asset_identifiers`/`market_calendars` 建好并 seeded（MVP 市场：US/JP/AU/HK/CN/EU 指数 + 主要资产）
- [ ] `data_sources` 注册表落库，合规台账同步（DATA_SOURCE_COMPLIANCE.md）
- [ ] MarketCollector（至少 crypto 免费源 + 1 个 licensed vendor sandbox）→ raw → normalize → Redis/PG 全链路跑通
- [ ] NewsCollector（≥3 个 RSS 源）+ 去重（§35）跑通
- [ ] CalendarCollector（官方源，High Impact 事件）跑通
- [ ] 数据质量校验 + quarantine（§36）+ `data_freshness_monitor`（§39）上线
- [ ] Collector 测试套件（§59 六项）

### Phase 2 — Backend
- [ ] FastAPI 骨架 + Alembic + OpenAPI 自动生成
- [ ] Auth：email + Google + Apple（JWT access/refresh）
- [ ] REST：markets/assets/chart/search/news/calendar/watchlist/portfolio/alerts（API.md §2–3）
- [ ] `/ws/quotes`：snapshot→delta、心跳、重连提示（§25.1）
- [ ] Search：pg_trgm，P95<500ms（AC-004）
- [ ] Alert Engine：评估 + cooldown + trigger_log（§15.1）
- [ ] 单测核心服务 ≥80%（§54）

### Phase 3 — Web
- [ ] §70 七页（mock → 真实）
- [ ] i18n（en/ja/zh-CN）+ dark mode + Asian color mode（§30.3）
- [ ] SEO：asset 页 SSR/OG/结构化数据（§63）
- [ ] Live/Delayed 标注（AC-003）、offline/empty/error/loading 四态（§76）
- [ ] Playwright E2E（§55）+ WCAG 2.1 AA（§62）

### Phase 4 — Mobile
- [ ] Flutter 5-tab（§29）；Home/Markets/Watchlist/News/Me
- [ ] 离线缓存 + Offline 态（AC-009）
- [ ] 操作步数验收（§61）：加自选 ≤2 tap、搜索 ≤2、设告警 ≤3、看图 ≤2
- [ ] 移动端自动化测试（§56）

### Phase 5 — Alert & Push
- [ ] FCM/APNs 端到端；触发→送达 P95<5s（AC-008）
- [ ] in-app 通知中心 + 通知偏好
- [ ] Web Notification

### Phase 6 — QA
- [ ] k6：1,000 API 并发 + 10,000 WS（§58），error<1%，P95<500ms
- [ ] Failover：单源失败 retry/log/alert/fallback（AC-010）
- [ ] HTML 结构变更不 crash collector（§59）
- [ ] CI/CD 全链路（§65）+ staging 验收

## 里程碑顺序建议（每块 = 若干 session）

1. Repo 骨架 + Alembic + asset master seed + 一个 collector 端到端（crypto）
2. Backend 核心只读 API（markets/assets/search）+ WS
3. Web 首页 + 资产页（mock → 真实）
4. Auth + Watchlist（Web）
5. News + Calendar（前后端）
6. Alert Engine + in-app 通知
7. Mobile 主体
8. Push 端到端
9. Portfolio（Phase 1.5）
10. Admin + 压测 + 上线
