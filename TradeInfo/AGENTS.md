# AGENTS.md — SimpleMarket

权威需求文档：`SimpleMarket_Devin_AI_REQUIREMENTS.md`（下称 REQUIREMENTS）。
规划文档：`docs/`。技术决策：`docs/adr/`。冲突时以 REQUIREMENTS 为准。

## Repo 结构

```text
web/               Next.js + TypeScript（§27）
mobile/            Flutter（ADR-0003）
backend/           Python FastAPI（ADR-0002）
collectors/        Python 数据采集器（§19）
infra/terraform/   GCP IaC（§66）
infra/local/       本地开发依赖（docker-compose: postgres + redis）
docs/              Phase 0 规划文档 + adr/
```

## 常用命令

```bash
# 本地依赖
docker compose -f infra/local/docker-compose.yml up -d

# backend（代码落地后）
cd backend && pip install -r requirements-dev.txt
cd backend && alembic upgrade head          # DB migration
cd backend && pytest                        # unit + integration
cd backend && ruff check . && mypy .        # lint + typecheck
cd backend && uvicorn app.main:app --reload # run

# web
cd web && pnpm install
cd web && pnpm dev                          # run
cd web && pnpm lint && pnpm typecheck
cd web && pnpm test                         # unit
cd web && pnpm e2e                          # Playwright（§55）

# mobile
cd mobile && flutter pub get && flutter test
cd mobile && flutter run                    # 需要模拟器/真机

# collectors
cd collectors && pytest

# infra
cd infra/terraform && terraform fmt -check -recursive && terraform validate
```

## 硬性规则（违反 = PR 拒绝）

1. **行情红线**：报价数据只允许 Official / Exchange / Licensed API。禁止任何爬取行情再发布的代码（REQUIREMENTS §17）。
2. **不提交 secret**：无 `.env*`、无凭据。生产 secret 走 Google Secret Manager（§67）。
3. **UI 文本必须走 i18n**，禁止 hardcoded 文案（§31）。MVP 语言：en / ja / zh-CN。
4. **stale 数据禁止标记为 Live**（§39）；freshness 判断必须结合 `market_calendars` 开闭市时间。
5. **MVP 范围外功能不做**：trading、broker 接入、AI 预测、社区、screener 等（§50）。新增功能前先回答 §78 的 5 个问题。
6. **数据库变更必须走 Alembic migration**，且向后兼容（Cloud Run 滚动发布）。
7. 新闻只存标题 + 摘要 + 来源链接，**不转载全文**（§13）。
8. 日志 JSON 格式、禁止敏感信息（§41）。

## 工作方式（§52 / §52.1）

- Plan → Implement → Test → Run → Validate → Commit，单里程碑粒度。
- 一次会话只交付一个可测试增量 = 一个 PR（`feature/*` 或 `fix/*` 分支 → `develop`）。
- Commit 用 Conventional Commits（`feat:` / `fix:` / `chore:` …）。
- 跨会话决策必须写 `docs/adr/`，不要只留在对话里。
- 所有接口变更先改 `docs/API.md` / OpenAPI spec，再改实现（contract-first）。
