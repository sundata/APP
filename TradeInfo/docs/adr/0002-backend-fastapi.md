# ADR-0002: Backend — Python FastAPI

- Status: Accepted
- Date: 2026-09-11

## Context

REQUIREMENTS §26 候选：Python FastAPI 或 TypeScript NestJS。要求 async、OpenAPI、单测/集成测试、WebSocket、Redis、PostgreSQL。

## Decision

FastAPI（Python 3.12）+ Alembic + pytest。

理由：
1. collectors（§19）已定 Python——后端与采集器同语言，data normalize/validate 逻辑可共享包，减少一套工具链
2. FastAPI 原生 async + 自动生成 OpenAPI（§25.2 contract-first、§70 mock 的直接依赖）
3. WS、Redis、SQLAlchemy 生态成熟

## Consequences

- (+) backend/collectors 共享 Python 依赖与数据模型
- (+) OpenAPI 由代码注解自动生成，契约不易漂移
- (−) Python 在极高并发下弱于编译型——由 Cloud Run 水平扩展 + Redis 读路径缓解；WS 层若压测不达标按 §25.1 拆独立服务
