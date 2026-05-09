# 🔥 Firebase 推送通知配置快速指南

## 📍 Firebase 项目设置路径

```
https://console.firebase.google.com
    ↓
🏠 Firebase 主页
    ↓
🟡 创建新项目 (Create Project)
    或
📋 选择现有项目 (Select Existing Project)
    ↓
项目设置
```

---

## 🎯 第一步: 创建或选择 Firebase 项目

### 【新项目】

```
Firebase 主页
    ↓
🟡 项目名称
│  └─ "SeeNews" (建议名称)
│
├─ 启用 Google Analytics
│  └─ ✓ 推荐启用，但非必需
│
└─ 🟢 "创建项目" (Create Project)
```

### 【现有项目】

如果已经有 Firebase 项目（用于其他功能），使用该项目。

---

## 🛠️ 第二步: 启用 Cloud Messaging

**位置**: Firebase 项目 > 构建 (Build)

```
项目主页
    ↓
🔨 构建 (Build) - 左侧菜单
    ↓
📢 Cloud Messaging
    ↓
👁️ 点击 "Cloud Messaging"
    ↓
🟢 启用 API (Enable API)
```

---

## 🔐 第三步: 生成服务账户密钥

**位置**: Firebase 项目设置 > 服务账户

### 步骤 1: 进入项目设置

```
项目主页 (右上角)
    ↓
⚙️ 项目设置 (Project Settings)
```

### 步骤 2: 切换到"服务账户"标签

```
项目设置页面
    ↓
📋 标签页:
    ├─ 常规 (General)
    ├─ 集成 (Integrations)
    ├─ 云消息传递 (Cloud Messaging)
    └─ 服务账户 ← 【点击这里】
```

### 步骤 3: 生成密钥

```
服务账户标签
    ↓
🔑 Firebase Admin SDK
    ↓
💾 "生成新密钥" (Generate New Private Key)
    ↓
🟡 选择 JSON 格式
    ↓
✅ 确认
    ↓
📥 文件自动下载: firebase-adminsdk-*.json
```

---

## 📁 第四步: 移动密钥文件到项目

### 位置配置

```bash
下载的文件位置:
    ~/Downloads/firebase-adminsdk-*.json

目标位置:
    /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/
        └─ API/
            └─ firebase-credentials.json
```

### 操作步骤

```bash
# 1. 打开终端
cd /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/API

# 2. 移动文件 (将下载的文件名替换为实际名称)
mv ~/Downloads/firebase-adminsdk-*.json firebase-credentials.json

# 3. 验证文件
ls -la firebase-credentials.json
```

### 文件内容示例

配置文件应包含:

```json
{
  "type": "service_account",
  "project_id": "seenews-backend",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@seenews-backend.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

---

## 📱 第五步: 配置 APNs 推送证书

Firebase 需要 Apple Push Notification 证书才能将消息推送到 iOS

### 在 Firebase 中配置 APNs

**位置**: Firebase 项目 > 设置 > Cloud Messaging

```
项目设置
    ↓
⚙️ 项目设置 (Project Settings)
    ↓
📢 云消息传递 (Cloud Messaging) 标签页
    ↓
🍎 Apple 配置
    ├─ APNs 认证密钥
    ├─ APNs 证书
    └─ 上传或配置证书
```

### 获取 APNs 证书

**位置**: Apple Developer > Certificates

```
https://developer.apple.com/account/resources/
    ↓
🔑 证书、标识符和配置文件 (Certificates, Identifiers & Profiles)
    ↓
🧾 证书 (Certificates)
    ↓
🟢 "新建证书" (Create a New Certificate)
    ↓
📱 Apple Push Notification service (APNs)
    ├─ APNs SSL/TLS 认证密钥 (推荐)
    │  └─ 【选择这个】
    │
    └─ APNs SSL/TLS 证书 (旧方式)

选择密钥类型:
    ↓
🆔 选择应用: "3秒ニュース"
    ↓
📥 下载密钥文件
    ↓
📋 复制密钥内容
```

### 在 Firebase 中上传

```
Firebase Cloud Messaging 设置
    ↓
🍎 Apple 配置
    ↓
📝 APNs 认证密钥
    ├─ 键ID (Key ID): (从 Apple Developer 复制)
    ├─ 团队ID (Team ID): (从 Apple Developer 复制)
    ├─ 捆绑ID (Bundle ID): com.3secnews.app
    └─ 私钥 (Private Key): (粘贴下载的密钥内容)
    
🟢 "上传" (Upload)
```

---

## ✅ 验证配置清单

### 【Firebase 项目】
- [ ] 项目创建完成: ___________
- [ ] Cloud Messaging API: ✓ 启用
- [ ] 服务账户密钥: ✓ 生成并下载
- [ ] 密钥文件位置: `API/firebase-credentials.json` ✓ 存在

### 【APNs 配置】
- [ ] APNs 认证密钥: ✓ 获取
- [ ] Key ID: ___________
- [ ] Team ID: ___________
- [ ] 密钥在 Firebase 中: ✓ 上传

### 【后端配置】
- [ ] `requirements.txt` 已更新: ✓ firebase-admin>=6.4.0
- [ ] `notifications.py` 已创建: ✓ 存在
- [ ] `server.py` 已更新: ✓ 新增 5 个端点

---

## 🚀 第六步: 后端部署

### 部署脚本

```bash
cd /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore

# 方式 1: 使用自动部署脚本
bash deploy-notifications.sh

# 方式 2: 手动部署
cd API
pip install -r requirements.txt
gcloud run deploy newsnow-backend \
  --source . \
  --region asia-northeast1 \
  --project seenews-backend \
  --allow-unauthenticated \
  --set-env-vars "FIREBASE_CREDENTIALS_PATH=/workspace/firebase-credentials.json"
```

---

## 🧪 测试推送通知

### 测试端点 (在后端部署后)

```bash
# 1. 注册设备 (获取 FCM token)
curl -X POST https://newsnow-backend-327343217815.asia-northeast1.run.app/v1/notifications/register-device \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "user_id": "test-user",
    "platform": "ios"
  }'

# 2. 发送测试通知
curl -X POST https://newsnow-backend-327343217815.asia-northeast1.run.app/v1/notifications/send-test \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "title": "テスト通知",
    "body": "Firebase 配置成功！"
  }'
```

### iOS 应用中获取 FCM Token

Firebase SDK 在启动时自动生成，查看日志：

```
Xcode 控制台输出:
    ↓
🔥 Firebase initialized
    ↓
📱 FCM Token: (长字符串)
    └─ 复制此 token 用于测试
```

---

## 📊 验证部署成功

### 后端日志检查

```bash
# 查看 Cloud Run 部署日志
gcloud run logs read newsnow-backend \
  --region asia-northeast1 \
  --project seeneas-backend \
  --limit 50
```

### 期望的日志输出

```
✅ 配置正确:
  - "Firebase initialized successfully"
  - "Notification sent to device_token"
  - "Device registered: device_id"

❌ 配置错误:
  - "Firebase initialization failed: ..."
  - "FIREBASE_CREDENTIALS_PATH not set"
```

---

## ⏰ 预期时间表

| 步骤 | 时间 | 状态 |
|------|------|------|
| 创建 Firebase 项目 | 1 分钟 | 立即 |
| 启用 Cloud Messaging | 1 分钟 | 立即 |
| 生成服务账户密钥 | 2 分钟 | 立即 |
| 获取 APNs 证书 | 3 分钟 | 立即 |
| 在 Firebase 中配置 APNs | 2 分钟 | 立即 |
| 后端部署 | 3-5 分钟 | ⏳ 部署中 |
| 功能测试 | 5 分钟 | ✅ 完成 |
| **总计** | **~17-20 分钟** | ✅ 完成 |

---

## 🚨 故障排除

### ❌ "Firebase initialization failed"

```
原因: firebase-credentials.json 文件缺失或无效
解决方案:
  1. 检查文件位置: API/firebase-credentials.json
  2. 验证 JSON 格式: cat API/firebase-credentials.json
  3. 重新下载密钥: Firebase > 项目设置 > 服务账户 > 生成新密钥
```

### ❌ "FIREBASE_CREDENTIALS_PATH not set"

```
原因: Cloud Run 环境变量未设置
解决方案:
  1. 运行部署脚本: bash deploy-notifications.sh
  2. 或手动设置: --set-env-vars "FIREBASE_CREDENTIALS_PATH=/workspace/..."
  3. 验证: gcloud run describe newsnow-backend --region asia-northeast1 --project seeneas-backend
```

### ❌ "APNs Authentication key is invalid"

```
原因: APNs 密钥格式错误或过期
解决方案:
  1. 重新生成 APNs 密钥: Apple Developer
  2. 确保包含 -----BEGIN PRIVATE KEY----- 和 -----END PRIVATE KEY----- 行
  3. 在 Firebase 中重新上传: Project Settings > Cloud Messaging > APNs
```

### ❌ "Device not receiving notifications"

```
原因: 推送权限未授予或 token 已过期
解决方案:
  1. [iOS] 确认已请求通知权限: 设置 > 通知 > 3秒ニュース > ✓ 允许
  2. 重新启动应用以刷新 FCM token
  3. 检查 APNs 证书是否配置: Firebase > Cloud Messaging
  4. 查看服务器日志: gcloud run logs read
```

---

## 📚 参考资源

- **Firebase Admin SDK**: https://firebase.google.com/docs/admin/setup
- **Cloud Messaging 文档**: https://firebase.google.com/docs/cloud-messaging
- **iOS 集成指南**: https://firebase.google.com/docs/cloud-messaging/ios/client
- **APNs 设置**: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server

---

## 🎯 完成确认

配置完成后，验证所有组件：

```bash
# 1. 检查 Firebase 文件
ls -la API/firebase-credentials.json

# 2. 检查 Python 依赖
pip show firebase-admin

# 3. 查看后端日志
gcloud run logs read newsnow-backend --region asia-northeast1 --project seeneas-backend --limit 10

# 4. 发送测试通知并观察 iOS 应用
# 应该在通知中心看到测试消息
```

完成后，告诉我结果，我们可以进行端到端测试！

