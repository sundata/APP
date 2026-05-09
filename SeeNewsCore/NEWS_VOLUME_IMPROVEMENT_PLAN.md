# 📊 新闻数量不足诊断和改进方案

## 🔍 问题根源分析

### 1️⃣ **数据保留期限过短** ⚠️
```python
# API/server.py 第 749-751 行
cutoff = datetime.now(timezone.utc) - timedelta(days=7)  # ← 只保留 7 天
deleted = db.query(ArticleORM).filter(
    ArticleORM.published_at < cutoff
).delete()
```

**后果**: 7 天前的所有新闻都被删除，导致数据库始终只有最近 7 天的新闻

### 2️⃣ **爬虫运行频率** 
```python
FETCH_INTERVAL_MINUTES = 5  # 每 5 分钟运行一次
```

**分析**: 
- 5 分钟运行一次还可以
- 但只保留 7 天，导致总数据量有限

### 3️⃣ **并发限制**
```python
batch_size = 5  # 最多同时获取 5 条 Yahoo 文章
og_batch = 20   # OG 图片最多 20 条
```

**影响**: 这个限制是合理的（防止被 block），但同样限制了数据量

---

## 📈 当前配置统计

| 项目 | 值 | 备注 |
|------|-----|------|
| RSS 源总数 | **16 个** | 覆盖 8 个分类 |
| 爬虫间隔 | 5 分钟 | 每小时 12 次 |
| 历史保留 | **7 天** | ❌ 太短 |
| 每次爬虫最大 | ~200 条 | 16 个源 × ~12-15 条 |
| 理论最大数据库 | ~7000 条 | 200 × 7 × 5 (间隔) |

---

## ✅ 改进方案

### 方案 A: 增加历史保留期
```python
# 改为 30 天
cutoff = datetime.now(timezone.utc) - timedelta(days=30)
```

**优点**:
- 数据量增加 4 倍
- 用户可以查看一个月前的新闻
- 不影响爬虫性能

**缺点**:
- 数据库容量增加
- Neon 免费版可能有限制

### 方案 B: 增加 RSS 源数量
当前有 16 个源，可以增加到 20-25 个，包括：
- 更多地区媒体
- 垂直领域新闻源
- 国际英文新闻源

### 方案 C: 优化爬虫并发
```python
# 增加并发数（需要谨慎，防止被 block）
batch_size = 10  # Yahoo: 5 → 10
og_batch = 40    # OG: 20 → 40
```

**风险**: 可能被服务器 block，需要加上随机延迟

### 方案 D: 混合方案（推荐）
1. 增加历史保留期: 7 天 → 30 天 (+400%)
2. 增加 RSS 源: 16 个 → 20 个 (+25%)
3. 合理增加并发: 批次 +50%

**预期效果**: 数据量增加 **5-6 倍**

---

## 🚀 立即可实施的改进

### 改进 1: 扩展历史保留期

**文件**: `API/server.py`
**位置**: 第 749 行

```diff
- cutoff = datetime.now(timezone.utc) - timedelta(days=7)
+ cutoff = datetime.now(timezone.utc) - timedelta(days=30)  # 增加到 30 天
```

**效果**: 数据库新闻数量 × 4

---

### 改进 2: 添加更多 RSS 源

**当前 16 个源**，建议新增：

```python
# 补充经济商业
{
    "name": "Bloomberg Japan",
    "url": "https://www.bloomberg.co.jp/feed/rss.xml",
    "category": "business",
    "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
},

# 补充国际新闻
{
    "name": "France 24",
    "url": "https://www.france24.com/en/rss.xml",
    "category": "overseas",
    "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
},

# 补充技术新闻
{
    "name": "TechCrunch",
    "url": "https://techcrunch.com/feed/",
    "category": "tech",
    "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
},

# 补充电影娱乐
{
    "name": "Deadline Hollywood",
    "url": "https://deadline.com/feed/",
    "category": "movie",
    "ua": "Mozilla/5.0 (compatible; FeedFetcher/1.0)",
},
```

**预期**: 增加 20-40 条新闻 / 每次爬虫

---

### 改进 3: 提高并发数

**文件**: `API/server.py`
**位置**: 第 695-720 行

```diff
- batch_size = 5
+ batch_size = 10  # Yahoo 详情并发 ×2

- batch = need_og[:20]
+ batch = need_og[:40]  # OG 图片并发 ×2
```

**效果**: 加速爬虫执行，可能增加抓取数量

---

## 📋 快速对比

| 指标 | 当前 | 改进后 | 增长 |
|------|------|--------|------|
| 保留期 | 7 天 | 30 天 | **+328%** |
| RSS 源 | 16 个 | 20 个 | **+25%** |
| 每次爬虫文章 | ~200 | ~250 | **+25%** |
| 数据库最大 | ~7,000 | ~30,000 | **+328%** |
| 用户可查看 | 1 周 | 1 月 | **+4 倍** |

---

## 实施步骤

### 步骤 1: 修改保留期（必须）
```bash
# 编辑 API/server.py
# 第 749 行: timedelta(days=7) → timedelta(days=30)
```

### 步骤 2: 添加 RSS 源（推荐）
```bash
# 编辑 API/server.py  
# RSS_SOURCES 列表中添加 4-5 个新源
```

### 步骤 3: 部署更新
```bash
cd /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/API
gcloud run deploy newsnow-backend --source . --region asia-northeast1
```

### 步骤 4: 监控效果
```bash
# 部署后观察 Cloud Run 日志
gcloud run logs read newsnow-backend --region asia-northeast1 --limit 100
```

---

## ⚠️ 注意事项

### 容量考虑
- **Neon 免费版**: 一般有 5GB 存储限制
- **预估空间**: 每条新闻 ~2KB → 30,000 条 ≈ 60MB （远小于 5GB）
- **安全性**: 单条新闻可能最大 10KB → 300MB，仍在限制内

### 性能考虑
- 查询 30,000 条记录仍然很快（带索引）
- 删除旧记录时锁表风险需注意
- 可以设置每天凌晨 2 点执行删除

### 源的稳定性
- 新增源需要验证响应速度
- 添加错误处理，防止单个源故障影响全体
- 建议监控源的可用性

---

## 🎯 推荐方案

**立即实施**:
1. ✅ 修改保留期: 7 天 → 30 天
2. ✅ 添加 4 个新 RSS 源
3. ✅ 部署更新

**预期结果**: 
- 新闻总量增加 **400%+**
- 用户体验大幅改善
- 查询响应时间 < 100ms

---

## 📝 后续优化

如果还需要更多新闻：
1. 扩展到 45-60 天历史
2. 添加 30+ RSS 源
3. 实现新闻去重和聚合
4. 添加用户自定义源

---

**建议**: 先实施本方案的 3 个改进，1 周后评估效果再考虑进一步扩展。

