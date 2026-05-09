# SeeNewsCore 部署指南

## 项目隔离架构

### 目前状态
- ✅ **ikiteru-2026** - 旧项目（包含 ikiteru-backend）
  - newsnow-backend v0014 正在运行
  - URL: https://newsnow-backend-984996167420.asia-northeast1.run.app
  
- 🔄 **seenews-backend** - 新项目（待完成）
  - 项目 ID: seenews-backend
  - 状态: 已创建，Billing 已关联，待部署 newsnow-backend

---

## 快速启用独立项目方案

### 方案 1️⃣: 使用 gcloud CLI（推荐）

```bash
# 1. 切换到新项目
gcloud config set project seenews-backend

# 2. 启用 Artifact Registry（如未启用）
gcloud services enable artifactregistry.googleapis.com

# 3. 创建 Docker 仓库
gcloud artifacts repositories create docker-repo \
  --repository-format=docker \
  --location=asia-northeast1

# 4. 配置 Docker 认证
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# 5. 部署到 Cloud Run
cd ~/WorkBuddy/20260412212940/SeeNewsCore/API
gcloud run deploy newsnow-backend \
  --source . \
  --region asia-northeast1 \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi \
  --min-instances 1
```

### 方案 2️⃣: 使用 Cloud Console UI

1. 访问 [Google Cloud Console](https://console.cloud.google.com)
2. 选择 **seenews-backend** 项目
3. 导航到 **Cloud Run**
4. 点击 **Create Service**
5. 选择 **Deploy from source code**
6. 上传 `/API` 目录
7. 配置:
   - Service name: `newsnow-backend`
   - Region: `asia-northeast1`
   - CPU: 1
   - Memory: 512MB
   - Min instances: 1
   - Allow unauthenticated: ✓

---

## URL 配置

部署成功后，新的后端 URL 将是：
```
https://newsnow-backend-[PROJECT_NUMBER].asia-northeast1.run.app
```

### 更新 iOS App

编辑以下文件中的 baseURL（替换为新 URL）:

1. **Services/NewsService.swift**
   ```swift
   private let baseURL = "https://newsnow-backend-[NEW_PROJECT_NUMBER].asia-northeast1.run.app/v1"
   ```

2. **Services/AIAnalysisService.swift**
   ```swift
   private let baseURL = "https://newsnow-backend-[NEW_PROJECT_NUMBER].asia-northeast1.run.app/v1"
   ```

3. **Services/PurchaseManager.swift**
   - verifyReceiptWithServer() 中的 baseURL
   - notifyServerPurchase() 中的 baseURL

---

## 当前工作完成情况

### ✅ 已完成
- [x] 新建 seenews-backend 项目（Project ID: seenews-backend）
- [x] 关联 Billing 账户（AI_WORK）
- [x] 启用 Cloud Run 和 Cloud Build 服务
- [x] iOS App 中所有 API 调用已改回 newsnow-backend（原项目）
- [x] RSS 源已优化为稳定的日本新闻源：
  - NHK（官方媒体）
  - Yahoo Japan（覆盖最广）
  - ITmedia（科技类）
- [x] iOS UI 改进：无图片新闻现在显示优化布局

### ⏳ 待完成
- [ ] 在 seenews-backend 项目中完成 newsnow-backend 部署
  - 原因：Docker 构建在新项目首次部署时需要 Artifact Registry 配置
  - 解决方案：按上述 gcloud CLI 方案继续

---

## 重要说明

### 安全隔离
- 新项目 `seenews-backend` 完全独立于 `ikiteru-2026`
- 资源、权限、API 配额、账单单独计算
- 符合微服务最佳实践

### 当前数据保留
- ikiteru-2026 项目中的 newsnow-backend 已有 **238 篇新闻数据**
- 迁移到新项目后，需要重新爬取 RSS 源（5 分钟内会自动填充）

---

## 故障排查

### 部署超时
```bash
# 查看云构建日志
gcloud builds log [BUILD_ID] --stream

# 查看 Cloud Run 服务日志
gcloud run services logs read newsnow-backend --region asia-northeast1 --limit=50
```

### 常见问题

**Q: Artifact Registry 错误**
A: 需要先创建仓库：
```bash
gcloud artifacts repositories create docker-repo \
  --repository-format=docker \
  --location=asia-northeast1
```

**Q: 权限不足**
A: 确保 gcloud 已认证：
```bash
gcloud auth login
```

---

## 下一步

1. **完成独立项目部署** （使用上述方案 1 或 2）
2. **获取新 URL** 并更新 iOS App
3. **验证 API** 连接
4. **将 ikiteru-backend 从 ikiteru-2026 删除**（可选，如不再需要）

