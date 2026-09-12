# SimpleMarket

简洁的全球行情资讯平台 — 行情 / 新闻 / 财经日历 / 自选 / 提醒。
**不提供交易功能**（§1）。

## 结构

| 目录 | 内容 |
|---|---|
| `backend/` | FastAPI + SQLAlchemy + Alembic；REST `/api/v1` + WS `/ws/quotes` |
| `collectors/` | 独立采集器：market mock / news RSS / calendar；retry+backoff+circuit breaker+failover |
| `api/openapi.yaml` | API 权威契约 |
| `web/` | Next.js 14（zh/en/ja、dark、红涨绿跌、WS 实时价） |
| `mobile/` | Flutter（5 tab、离线快照缓存） |
| `infra/terraform/` | GCP：Cloud Run / Cloud SQL / Memorystore / BigQuery / Scheduler / Budget |
| `perf/k6/` | 压测脚本（1k API 并发 / 10k WS） |
| `docs/` | Phase 0 规划 + ADR |

## 本地跑

```bash
cd backend && python -m venv .venv && .venv/bin/pip install -r requirements.txt -e .
.venv/bin/alembic upgrade head
.venv/bin/uvicorn app.main:app --reload        # http://localhost:8000

cd ../collectors && PYTHONPATH=.:../backend ../backend/.venv/bin/python -m collector.market

cd ../web && npm install && npm run dev      # http://localhost:3000
cd ../mobile && flutter run                  # needs Flutter SDK
```

## 测试

```bash
backend/.venv/bin/pytest backend/            # 94 tests
backend/.venv/bin/pytest collectors/         # 55 tests
backend/.venv/bin/mypy backend/app && backend/.venv/bin/ruff check backend/ collectors/
cd web && npm run e2e                        # Playwright §55 paths
```

## 关键约束

- 外部数据源 `enabled=false` 直到 terms/licensing 评审（§16-17）
- 新闻只存标题/摘要/链接，不存全文（§35）
- freshness 五态（live/delayed/stale/closed/no_data）每个价格旁必显（§39）
- WebSocket 断线须能 resync（§25）；通知 push 走可注入 sender，FCM/APNs 部署期接入
