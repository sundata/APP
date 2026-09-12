# ADR-0003: Mobile — Flutter

- Status: Accepted
- Date: 2026-09-11

## Context

REQUIREMENTS §28 候选：Flutter 或 React Native。要求 iOS/Android 共用代码、UI 一致、开发速度快、WebSocket 支持良好；§28 明确要求记录最终选择理由。

## Decision

Flutter（stable channel）。

理由：
1. 单 codebase 双端 UI 高度一致——契合 "Simple/Fast" 产品原则与小团队维护成本
2. `web_socket_channel`、Riverpod/Bloc、fl_chart 等生态覆盖本项目需求（WS、状态管理、K线图）
3. 自动化测试路径清晰：`integration_test` / Patrol（§56）
4. RN 的 JS 生态复用价值对本项目有限（web 已是独立 Next.js 应用，不共享组件）

## Consequences

- (+) 双端一套代码、一套 UI、一套测试
- (−) Dart 人才面窄于 JS——可接受
- (−) Devin sandbox 需装 Flutter SDK（已写入 environment.yaml，snapshot 一次性成本）
