# 📋 诊断报告：应用问题分析

## 🔍 用户报告的问题

### 问题 1: 政治家 Tab 点击后跑到屏幕中间 ❌
**症状**: 点击"政治家"分类后，Tab Bar 的位置会跳动
**原因**: CategoryTabBar 使用 ScrollView，当 Tab 不在视图范围内时，会自动滚动到中间
**位置**: [Views/CategoryView.swift](Views/CategoryView.swift) - CategoryTabBar 结构

### 问题 2: 政治家分类没有新闻 ❌
**症状**: 打开政治家(Politics)分类显示空白
**原因分析**:
- ✅ 后端有 Yahoo Japan Politics RSS 源 (server.py 第 107-110 行)
- ❓ 可能是:
  1. RSS 源当前没有新闻
  2. 分类映射错误 (politics 对应错误的分类)
  3. API 响应问题

### 问题 3: 整体新闻不够 ⚠️
**原因分析**:
- 当前只有 1 个政治类 RSS 源 (Yahoo Japan Politics)
- 相比其他分类，政治源较少
- **需要**: 添加更多政治类 RSS 源

### 问题 4: 历史新闻显示 ❓
**症状**: 应用是否显示过去的新闻（而非仅最新）
**现状**: 
- API 支持分页 (page 参数)
- 每页 100 条记录
- 数据库应该保留历史记录

### 问题 5: 上下滑动时加载新闻（无限滚动）❓
**症状**: 滚动时是否自动加载更多新闻
**现状**:
- ✅ NewsViewModel 有 loadMore() 方法
- ✅ 但可能没有在 UI 中正确触发

---

## ✅ 解决方案

### 问题 1: Tab 跳动修复 ✓
**改进**: 让选中的 Tab 自动滚动到视图范围内的左侧，而不是中间
**文件**: CategoryTabBar (CategoryView.swift)
**方法**: 使用 ScrollViewReader 和 onAppear 定位

### 问题 2/3: 新闻不足修复 ✓
**改进**: 添加更多政治类 RSS 源
**文件**: API/server.py
**方法**: 添加政治相关新闻源:
- News24Japan（政治関連）
- Jiji Press（官方新闻社，政治报道多）
- 等等

### 问题 4: 历史新闻 ✓
**现状**: 应用已支持，但可能用户未发现
**改进**: 在主页添加"加载更多"按钮

### 问题 5: 无限滚动 ✓
**改进**: 在新闻列表底部添加"加载更多"触发
**实现**: 检测到最后一条新闻时自动加载下一页

---

## 📊 当前 RSS 源统计

| 分类 | 源数 | 源名称 |
|------|------|--------|
| General | 5 | NHK x3, Yahoo Japan x1, Asahi x1 |
| Sports | 2 | Yahoo Japan Sports, Sports Hochi |
| Business | 1 | Yahoo Japan Business |
| Celebrity | 2 | Yahoo Japan Entertainment, Sanspo |
| Tech | 1 | ITmedia |
| World | 1 | Yahoo Japan World |
| **Politics** | **1** | **❌ 只有 Yahoo Japan** |

**政治分类太少！需要添加 3-5 个源**

---

## 🔧 待修复的文件

### 必须修复
1. **[Views/CategoryView.swift](Views/CategoryView.swift)** 
   - 修复 Tab Bar 滚动定位问题

2. **[API/server.py](API/server.py)**
   - 添加更多政治类 RSS 源

3. **[Views/HomeView.swift](Views/HomeView.swift)**
   - 添加无限滚动触发（在列表底部）

### 可选改进
4. **NewsService** 
   - 优化历史新闻加载

---

## ⏱️ 预计修复时间

| 任务 | 时间 | 优先级 |
|------|------|--------|
| 修复 Tab 跳动 | 15 分钟 | 🔴 高 |
| 添加政治 RSS 源 | 10 分钟 | 🔴 高 |
| 添加无限滚动 | 20 分钟 | 🟡 中 |
| **总计** | **45 分钟** | ✅ |

