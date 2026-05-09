# 🛍️ App Store Connect IAP 配置完整指南

## 问题诊断

```
⚠️ Received 0 products
   → App Store Connect 中没有配置这些产品 ID
```

**原因**: 虽然 iOS 代码正确请求产品信息，但 App Store 端找不到对应的产品。

---

## 📱 Step-by-Step 配置指南

### ✅ 前置要求
- [ ] Apple Developer 账户 (已激活)
- [ ] App Store Connect 访问权限
- [ ] Bundle ID: `com.3secnews.app` 已注册

---

## 🎯 第 1 步: 访问 App Store Connect

1. 打开 [App Store Connect](https://appstoreconnect.apple.com)
2. 用 Apple ID 登录
3. 选择 **应用** 或 **My Apps**
4. 搜索并选择 **3秒ニュース** (或您的应用名称)

---

## 🎯 第 2 步: 创建订阅组 (Subscription Group)

### 2.1 导航到订阅配置
```
应用页面
  ├─ 功能 (Features) 或 管理 (Manage)
  └─ In-App Purchases (应用内购买)
```

### 2.2 创建订阅组
```
点击 "+" 按钮
  └─ 选择 "Subscription (订阅)"
     └─ 参考名称: "com.3secnews.pro"
```

**配置详情**:
| 字段 | 值 |
|------|-----|
| 参考名称 | `3秒ニュース Pro` |
| 订阅组 ID | `com.3secnews.pro` |

---

## 🎯 第 3 步: 创建订阅产品 (月度)

### 3.1 添加新订阅
```
In-App Purchases
  └─ 点击 "+"
     └─ 选择 "Subscription"
        └─ 选择订阅组 "com.3secnews.pro"
```

### 3.2 配置月度计划

**基本信息**:
| 字段 | 值 |
|------|-----|
| 产品 ID | `com.3secnews.pro.monthly` |
| 参考名称 | `Pro Plan - Monthly` |
| 订阅组 | `com.3secnews.pro` |

**定价和可用性**:
| 字段 | 值 |
|------|-----|
| 定价层级 | **日本: ¥680** |
| 审核票据 | 说明产品价值 |
| 订阅时长 | 1 个月 |
| 免费试用期 | 无 |
| 续订 | 自动续订 |

**应用商店信息**:
| 字段 | 值 |
|------|-----|
| 显示名称 | `3秒ニュース Pro - Monthly` |
| 描述 | `AI分析が使い放題。広告なし。` |

### 3.3 保存并提交审核

```
✓ 完成基本信息
✓ 完成定价
✓ 完成应用商店信息
→ 点击 "保存" 
→ 等待 Apple 审核
```

---

## 🎯 第 4 步: 创建订阅产品 (年度)

### 4.1 重复第 3 步，但使用：

**基本信息**:
| 字段 | 值 |
|------|-----|
| 产品 ID | `com.3secnews.pro.yearly` |
| 参考名称 | `Pro Plan - Yearly` |
| 订阅组 | `com.3secnews.pro` |

**定价和可用性**:
| 字段 | 值 |
|------|-----|
| 定价层级 | **日本: ¥6,800** |
| 订阅时长 | 1 年 |
| 续订 | 自动续订 |

**应用商店信息**:
| 字段 | 值 |
|------|-----|
| 显示名称 | `3秒ニュース Pro - Yearly` |
| 描述 | `年間で17%お得。AI分析使い放題。` |

---

## 🎯 第 5 步: 配置 APNs 推送证书

### 5.1 导航到证书管理
```
App Store Connect
  ├─ 应用 > 3秒ニュース
  ├─ 设置 (Settings)
  └─ 证书、标识符和配置文件
```

### 5.2 上传 APNs 证书

**如果您已有 .p8 密钥**:
```
1. 点击 "Apple Push Notification service (APNs)"
2. 上传 .p8 文件或粘贴密钥内容
3. 保存
```

**如果您没有密钥**:
```
参阅: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_certificate-based_server_trust_relationship
```

---

## 📊 产品状态检查清单

完成配置后，验证以下内容：

### ✅ 月度订阅
```
产品 ID:        com.3secnews.pro.monthly
状态:          可供出售 (Available for Sale)
定价:          ¥680
订阅期:        1 个月
自动续订:      启用
```

### ✅ 年度订阅
```
产品 ID:        com.3secnews.pro.yearly
状态:          可供出售 (Available for Sale)
定价:          ¥6,800
订阅期:        1 年
自动续订:      启用
```

### ✅ 推送通知
```
APNs 证书:     已配置
开发/生产:     已配置
```

---

## 🧪 在 Sandbox 中测试

### 测试账户创建

1. **App Store Connect > 用户和访问权限**
   ```
   ├─ 测试员 (Testers)
   └─ 沙箱用户 (Sandbox Users)
   ```

2. **创建沙箱测试账户**
   ```
   点击 "+"
   └─ 填写:
      ├─ 名字: Test User
      ├─ 电子邮件: test@example.com
      ├─ 国家/地区: 日本
      └─ 完成注册
   ```

3. **在设备上测试**
   ```
   iOS 设备
   ├─ 设置 > App Store
   ├─ 注销
   ├─ 使用沙箱账户登录
   └─ 在应用中测试购买
   ```

---

## 📝 故障排查

### 问题: "Still showing 'Received 0 products'"

**解决方案**:
1. ✓ 确认产品 ID 拼写正确
2. ✓ 产品状态必须是 "可供出售"
3. ✓ Bundle ID 必须匹配: `com.3secnews.app`
4. ✓ 等待 Apple 审核完成 (通常 1-24 小时)
5. ✓ 清除应用缓存: 设置 > 通用 > 存储空间 > 删除应用 > 重新安装

### 问题: 审核被拒绝

**常见原因**:
- 产品描述不清楚
- 缺少隐私政策
- 产品功能与说明不符

**解决方案**:
- 完整填写所有字段
- 添加清晰的屏幕截图
- 提供详细的产品说明

---

## ⏱️ 预期时间表

| 步骤 | 时间 |
|------|------|
| 创建产品 | 5 分钟 |
| Apple 审核 | 1-24 小时 |
| 在 Sandbox 测试 | 10 分钟 |
| 全面部署 | 1 小时 |

---

## 🔗 相关资源

- [App Store Connect Help - In-App Purchase](https://help.apple.com/app-store-connect/#/dev3a5f4da7)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [Testing Your In-App Purchase](https://developer.apple.com/documentation/storekit/testing_your_in-app_purchase)
- [App Store Connect User Guide](https://appleid.apple.com/account)

---

## ✨ 完成后的验证

一旦产品配置完成，应用日志应该显示：

```
📦 Requesting products for IDs: com.3secnews.pro.monthly, com.3secnews.pro.yearly
✅ Received 2 products
💾 Stored 2 products
  - com.3secnews.pro.monthly: ¥680
  - com.3secnews.pro.yearly: ¥6,800
```

---

## 📞 获得帮助

如果遇到问题：

1. **Apple Developer Support**: https://developer.apple.com/contact/
2. **App Store Connect Help**: https://help.apple.com/app-store-connect/
3. **应用开发社区**: Stack Overflow (tag: ios, in-app-purchase)

