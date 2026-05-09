# 🎯 App Store Connect IAP 快速参考卡

## 📍 在 App Store Connect 中的位置

```
https://appstoreconnect.apple.com
    ↓
🏠 主页
    ↓
📱 "应用" (Apps)
    ↓
🔍 搜索 "3秒ニュース" (或您的应用名称)
    ↓
应用详情页面
    ├─ 📋 概览 (Overview)
    ├─ ⚙️ 设置 (Settings)
    ├─ ✨ 功能 (Features)  ← 【第一步从这里开始】
    ├─ 📊 分析 (Analytics)
    └─ 📈 销售和趋势 (Sales and Trends)
```

---

## 🛍️ In-App Purchase 配置路径

### 方式 1: 通过"功能"菜单

```
应用详情页面
    ↓
✨ 功能 (Features)
    ↓
📋 (左侧菜单中找) In-App Purchases
    ↓
🟢 点击 "+"
    └─ 选择产品类型: "Subscription"
```

### 方式 2: 通过"设置"菜单

```
应用详情页面
    ↓
⚙️ 设置 (Settings)
    ↓
📋 应用内购买
    ↓
🟢 点击 "+"
```

---

## 📝 填写表单示例

### 【第一步】创建订阅组

```
┌─ 参考名称 (Reference Name)
│  └─ "3秒ニュース Pro"
│
├─ 订阅组 ID (Subscription Group ID)
│  └─ "com.3secnews.pro"
│
└─ 点击 "创建"
```

---

### 【第二步】创建月度订阅

**位置**: In-App Purchases > 🟢 新建 > Subscription > com.3secnews.pro

```
基本信息:
┌─ 产品 ID (Product ID)
│  └─ com.3secnews.pro.monthly
│
├─ 参考名称 (Reference Name)
│  └─ Pro Plan - Monthly
│
├─ 订阅组 (Subscription Group)
│  └─ com.3secnews.pro
│
└─ 状态 (Status)
   └─ 开发 (Development) → 准备就绪后改为 可供出售

定价和可用性:
┌─ 定价点 (Price Point)
│  ├─ 日本 (Japan)
│  └─ ¥680
│
├─ 审核票据 (Review Notes)
│  └─ "Monthly subscription for ad-free reading and AI analysis"
│
├─ 订阅周期 (Subscription Duration)
│  └─ 1个月
│
├─ 免费试用期 (Free Trial Period)
│  └─ 无 (None)
│
└─ 自动续订 (Auto-Renewable)
   └─ ✓ 启用

应用商店信息:
┌─ 显示名称 (Display Name)
│  └─ 3秒ニュース Pro - Monthly
│
├─ 描述 (Description)
│  └─ AI分析が使い放題。広告なし。
│
└─ 点击 "保存"
```

---

### 【第三步】创建年度订阅

**位置**: In-App Purchases > 🟢 新建 > Subscription > com.3secnews.pro

```
基本信息:
┌─ 产品 ID (Product ID)
│  └─ com.3secnews.pro.yearly
│
├─ 参考名称 (Reference Name)
│  └─ Pro Plan - Yearly
│
├─ 订阅组 (Subscription Group)
│  └─ com.3secnews.pro
│
└─ 状态 (Status)
   └─ 开发 (Development) → 准备就绪后改为 可供出售

定价和可用性:
┌─ 定价点 (Price Point)
│  ├─ 日本 (Japan)
│  └─ ¥6,800
│
├─ 审核票据 (Review Notes)
│  └─ "Annual subscription with 17% savings. Ad-free reading and unlimited AI analysis"
│
├─ 订阅周期 (Subscription Duration)
│  └─ 1年
│
├─ 免费试用期 (Free Trial Period)
│  └─ 无 (None)
│
└─ 自动续订 (Auto-Renewable)
   └─ ✓ 启用

应用商店信息:
┌─ 显示名称 (Display Name)
│  └─ 3秒ニュース Pro - Yearly
│
├─ 描述 (Description)
│  └─ 年間で17%お得。AI分析使い放題。広告なし。
│
└─ 点击 "保存"
```

---

### 【第四步】配置 APNs 推送证书

**位置**: 应用详情 > ⚙️ 设置 > 证书、标识符和配置文件

```
证书管理:
┌─ Apple Push Notification service (APNs)
│  ├─ 开发环境 (Development)
│  │  └─ 上传或创建证书
│  └─ 生产环境 (Production)
│     └─ 上传或创建证书
│
└─ 保存所有更改
```

---

## ✅ 状态检查清单

完成后，验证以下内容：

### 【月度订阅】
- [ ] 产品 ID: `com.3secnews.pro.monthly`
- [ ] 定价: ¥680
- [ ] 订阅周期: 1个月
- [ ] 状态: **🟢 可供出售** (Available for Sale)
- [ ] 自动续订: ✓ 启用

### 【年度订阅】
- [ ] 产品 ID: `com.3secnews.pro.yearly`
- [ ] 定价: ¥6,800
- [ ] 订阅周期: 1年
- [ ] 状态: **🟢 可供出售** (Available for Sale)
- [ ] 自动续订: ✓ 启用

### 【推送通知】
- [ ] APNs 开发证书: ✓ 配置
- [ ] APNs 生产证书: ✓ 配置

---

## 🧪 验证和测试

### 测试期望的日志输出

应用启动时，查看 Xcode 控制台：

```
✅ 配置正确时:
📦 Requesting products for IDs: com.3secnews.pro.monthly, com.3secnews.pro.yearly
✅ Received 2 products
💾 Stored 2 products
  - com.3secnews.pro.monthly: ¥680
  - com.3secnews.pro.yearly: ¥6,800

❌ 配置错误时:
📦 Requesting products for IDs: com.3secnews.pro.monthly, com.3secnews.pro.yearly
⚠️ Received 0 products
```

---

## ⏰ 预期时间表

| 步骤 | 时间 | 状态 |
|------|------|------|
| 创建订阅组 | 2 分钟 | 立即生效 |
| 创建月度产品 | 3 分钟 | 待审核 |
| 创建年度产品 | 3 分钟 | 待审核 |
| Apple 审核 | 1-24 小时 | ⏳ 等待 |
| 沙箱测试 | 10 分钟 | ✅ 产品可用 |
| **总计** | **~1-24 小时** | ✅ 完成 |

---

## 🚨 常见错误和解决方案

### ❌ "Product ID 已被使用"

**原因**: 产品 ID 已在另一个应用中使用
**解决方案**: 检查 Bundle ID 是否正确 (`com.3secnews.app`)

### ❌ "定价点不可用"

**原因**: 不是所有国家都支持该定价层
**解决方案**: 选择"日本"特定的价格，而不是全球默认

### ❌ "Cannot update while pending review"

**原因**: 产品正在 Apple 审核中
**解决方案**: 等待审核完成或创建新版本

### ❌ "Status must be 'Ready to Submit' before publishing"

**原因**: 状态未设置为"可供出售"
**解决方案**: 
  1. 选择产品
  2. 点击"编辑"
  3. 将状态改为 "可供出售"

---

## 📞 需要帮助?

1. **App Store Connect 帮助**: https://help.apple.com/app-store-connect/
2. **Apple 开发者支持**: https://developer.apple.com/contact/
3. **Stack Overflow**: 搜索 `ios in-app-purchase` 标签

---

## 🎯 完成确认

完成所有步骤后，回到终端运行：

```bash
cd /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore
bash check-iap-config.sh
```

然后重新编译并运行应用。日志应该显示"✅ Received 2 products"。

