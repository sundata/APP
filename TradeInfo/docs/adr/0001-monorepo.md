# ADR-0001: Monorepo

- Status: Accepted
- Date: 2026-09-11

## Context

平台含 web / mobile / backend / collectors / infra 五个技术栈不同的子项目（§52.1），由 Devin AI 分多个 session 开发，API 契约需要跨端严格一致。

## Decision

单 monorepo：

```text
web/  mobile/  backend/  collectors/  infra/  docs/
```

## Consequences

- (+) OpenAPI spec、共享类型、需求文档同库，跨端改动可在一个 PR 内完成
- (+) Devin 单 session 可触及全栈，契约漂移风险低
- (−) CI 需按目录过滤触发，避免无关 job
- (−) 目录级权限控制弱（如需拆分发布权限再评估）
