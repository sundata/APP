# DATA_SOURCE_COMPLIANCE.md — SimpleMarket

REQUIREMENTS §17、§44 的执行文件。**任何数据源上线前必须在本文件登记并通过评审**，同时写入 `data_sources` 表（`terms_reviewed=true` 才允许 `enabled=true`）。

## 1. 红线（不可协商）

1. **行情数据**（股票/指数/外汇/商品/债券报价）：只允许 Official / Exchange / Licensed API。**禁止爬虫采集后再发布**——"网页可访问" ≠ "允许商业再发布"（§44）。
2. **中国 A 股（SSE/SZSE）**：行情分发许可制度严格，上线前专项许可评估。
3. **新闻**：只存标题 + 摘要 + 来源链接，不转载全文；正文跳转来源（§13）。
4. 禁止 CAPTCHA bypass、登录绕过、反爬对抗（§19.1）。
5. 各源延迟要求（如 "delayed ≥15min"）写入 `data_sources.delay_minutes`，UI 据此标注。

## 2. 登记模板（每个源一条）

```text
source_id:
source_name:
base_url:
data_type:            quote / news / calendar / fundamental / reference
collection_type:      api / rss / scraper(非行情) / manual
ToS 链接:
API terms 链接:
robots.txt 结论:       (仅 scraper 需要)
copyright / 再发布:    allowed / restricted / prohibited / 待确认
商用许可:             yes / no / 待确认
attribution 要求:      (如需署名，写明形式)
delay 要求:           (如 15min)
market data licensing: (指数/交易所许可条款编号或合同)
评审人 / 日期:
结论:                 approved / rejected / conditional
```

## 3. 初始评审台账

| source | 类型 | 状态 | 主要风险 |
|---|---|---|---|
| Coinbase / Binance 公开行情 API | crypto quote | 待评审 | 公开 API 展示用途一般允许，再发布条款需逐字确认 |
| ECB 参考汇率 | forex | 待评审 | 免费使用政策宽松，但日更 → Level D |
| US Treasury | bond yield | 待评审 | 政府公开数据 |
| Fed/ECB/BOJ/RBA/BLS | news/calendar | 待评审 | 政府信息多可引用，仍需记录来源 |
| EDGAR | 公司公告 | 待评审 | SEC 公开数据，有 fair-access 条款 |
| 财经媒体 RSS（逐家） | news | 待评审 | 各家 ToS 差异大；只展示标题+链接最稳妥 |
| Licensed market data vendor（待选） | quotes 全类 | 待商务谈判 | 决定 MVP 行情覆盖度与成本；合同需覆盖 Web+App 双端再发布、用户数、延迟档位 |
| SSE/SZSE 行情 | stock_cn | 高风险 | 需专项许可；未获批前 `enabled=false` |

## 4. 流程

1. 新源提案 → 填模板 → 法务/负责人评审 → 结论写本文件
2. 通过后写 `data_sources`（`license_status`/`terms_reviewed`/`delay_minutes`）
3. 每季度复审一次（ToS 会变）；条款变更立即重评
4. 发现违规 → `enabled=false` + 清理已采数据 + 记录 `collector_errors`

## 5. 页面义务

- 全站 disclaimer（§45）三语
- 需署名的源在相应页面/页脚展示 attribution
- Privacy Policy（§43）说明数据收集与账号删除
