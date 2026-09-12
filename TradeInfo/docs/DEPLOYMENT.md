# DEPLOYMENT.md — SimpleMarket

## 1. 环境（§64）

| env | 用途 | 基建 |
|---|---|---|
| local | 开发 | docker-compose（postgres/redis）+ mock 数据源 |
| dev | 集成 | GCP dev 项目，Cloud Run scale-to-zero 允许（§69 夜间） |
| staging | 验收/压测 | 与 prod 同构，缩容版 |
| production | 线上 | 见下 |

生产数据不进 dev（§64）。

## 2. GCP 资源（Terraform 管理，§66）

```text
infra/terraform/
├── modules/            # cloud_run / cloudsql / redis / pubsub / storage / bigquery / monitoring
├── envs/
│   ├── dev/
│   ├── staging/
│   └── production/
```

| 资源 | 说明 |
|---|---|
| Cloud DNS + CDN + Load Balancer | 入口（§21） |
| Cloud Run | backend api、web、data-processor、alert-engine、notification-svc；collector 用 Cloud Run Jobs + Scheduler |
| Cloud SQL PostgreSQL 16 | private IP；prod 开 HA（99.9% 目标 §38）+ 每日备份 + PITR（§68） |
| Memorystore Redis | quotes/session/fan-out |
| Pub/Sub | market-data-raw、alert-triggers、notifications |
| Cloud Storage | `market-data-raw` + lifecycle（§20/§68） |
| BigQuery | 分区表 + quota（§69） |
| Secret Manager | 全部 secret（§67），IAM least privilege（§42） |
| Cloud Monitoring | §40 指标 + alerting；Error Reporting |
| Budget + Billing Alert | §69 |

## 3. CI/CD（GitHub Actions，§65）

```text
PR → lint → unit test → build → security scan
merge develop → deploy staging → E2E (Playwright + mobile suite)
manual/auto gate → deploy production (Cloud Run rolling)
```

- DB migration：CI 中 `alembic upgrade head` 先于服务发布；所有 migration 向后兼容
- 回滚：Cloud Run revision 回切 + Alembic downgrade（仅限兼容变更）

## 4. Secret 与凭据

- 一律 Secret Manager；CI 用 Workload Identity Federation，不用 SA key 文件
- Devin/本地开发只用 mock/emulator（environment.yaml）

## 5. 发布前检查单

- [ ] `data_sources` 中 enabled 的源均 `terms_reviewed=true`
- [ ] 每行情源 `delay_minutes` 正确，UI 标注符合 AC-003
- [ ] Disclaimer 三语到位（§45）
- [ ] Feature flags 默认符合 §49 MVP 范围
- [ ] 备份/PITR/预算告警生效
- [ ] 无 Critical/High 安全问题（§76）
