# ✅ App Store Connect Pro 月度订阅 - 完整检查清单

## 📋 App Store 配置进度追踪

### ✓ 已完成的步骤

- [x] 在 App Store Connect 中创建订阅组 `com.3secnews.pro`
- [x] 创建月度订阅产品: `com.3secnews.pro.monthly`
- [x] 基本信息已填写:
  - [x] 产品 ID: `com.3secnews.pro.monthly`
  - [x] 参考名: `Pro Monthly`
  - [x] 本地化名: `Proプラン`
  - [x] 描述: `AI分析無制限・深度解読・広告なし`
- [x] 定价设置: `¥680/月`
- [x] 订阅周期: `1 个月`
- [x] 家庭共享: `✓ 启用` (可选但推荐)

### ⏳ 待完成的步骤

#### 第 1 阶段：审查截图准备（📌 当前阶段）

- [ ] **1.1** 在 Xcode 中打开应用
  ```bash
  open /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/SeeNews.xcworkspace
  ```

- [ ] **1.2** 运行应用到 iPhone 14 Pro 模拟器
  - 选择设备: iPhone 14 Pro 或 iPhone 13 Pro
  - 点击 ▶️ Run 按钮

- [ ] **1.3** 获取截图 1：AI 分析功能
  - 操作: 打开文章 → 点击"3秒で理解"
  - 保存为: `screenshot_1_ai_analysis.png`
  - 📌 **这是最重要的截图**

- [ ] **1.4** 获取截图 2：无广告体验（推荐）
  - 操作: 返回主页，滚动查看新闻流
  - 保存为: `screenshot_2_no_ads.png`

- [ ] **1.5** 获取截图 3：价格页面（可选）
  - 操作: 点击设置 → 找到 Pro 订阅部分
  - 保存为: `screenshot_3_pricing.png`

- [ ] **1.6** 创建文件夹并整理
  ```bash
  mkdir -p ~/Desktop/AppStore_Screenshots
  # 复制所有截图文件到这个目录
  ```

#### 第 2 阶段：App Store Connect 上传

- [ ] **2.1** 登录 App Store Connect
  - URL: https://appstoreconnect.apple.com
  - Apple ID: 你的开发者账号

- [ ] **2.2** 上传审查截图
  - 应用 → In-App Purchases → Pro Monthly
  - 找到"スクリーンショット"部分
  - 点击"+"上传 1-5 张截图

- [ ] **2.3** 填写审查备注
  - 位置: 审查信息区域
  - 复制内容: 参考 `APPSTORE_REVIEW_NOTES.md`
  - 或使用模板:
    ```
    月額購読「Proプラン」について
    このアプリの AI 分析機能を無制限に使用できます。
    深度解読、将来予測、行動アドバイスも含まれます。
    広告表示なしの最良な体験を提供します。
    ```

- [ ] **2.4** 验证所有信息
  - [x] 产品 ID: `com.3secnews.pro.monthly`
  - [x] 价格: `¥680`
  - [x] 周期: `1个月`
  - [ ] 状态应显示: "完了 ✓" 或 "準備完了 ✓"

#### 第 3 阶段：应用版本关联

- [ ] **3.1** 在 Xcode 中更新应用版本
  ```
  Project.xcodeproj → Info tab
  Version: 1.0 → 1.1
  Build Number: 1 → 2
  ```

- [ ] **3.2** 编译并上传二进制文件
  ```bash
  # 在 Xcode 中:
  Product → Archive
  或
  Product → Scheme → Generic iOS Device (Release)
  然后 Product → Archive
  ```

- [ ] **3.3** 在 App Store Connect 中创建新应用版本
  - 应用 → Version
  - 点击"+"创建新版本
  - 版本号: 1.1

- [ ] **3.4** 上传二进制文件到新版本
  - 使用 Xcode 的 Organizer 窗口
  - 或使用 App Store Connect Upload

- [ ] **3.5** 在该应用版本中关联 Pro Monthly 订阅
  - 新版本页面 → "App 内購入とサブスクリプション" 部分
  - 选择 ✓ "Pro Monthly"

#### 第 4 阶段：提交审查

- [ ] **4.1** 填写完整的版本信息（如未填）
  - 版本号: 1.1
  - 发行说明: 适用于 1.1 版本
  - 可用性: 立即发布

- [ ] **4.2** 设置应用类别和内容评级（如未设置）
  - 类别: News
  - 内容评级问卷: 完成

- [ ] **4.3** 选择构建版本
  - 从列表中选择已上传的 v1.1 构建

- [ ] **4.4** 确认「App 内購入」包含 Pro Monthly
  - ✓ 已勾选 "Pro Monthly" 复选框

- [ ] **4.5** 点击"提出" (Submit for Review)
  - 最后确认所有信息
  - 点击"提出"按钮
  - 等待确认邮件

#### 第 5 阶段：审查等待

- [ ] **5.1** 等待 Apple 审查
  - 预期时间: 1-24 小时
  - 进度可在"App Store Connect"中查看

- [ ] **5.2** 根据结果采取行动
  
  **如果批准 ✅**:
  - [ ] 订阅将在新应用版本发布时激活
  - [ ] 现有用户可升级到 Pro
  - [ ] 监控订阅数量和收入
  
  **如果被拒 ❌**:
  - [ ] 阅读 Apple 的拒绝邮件
  - [ ] 按照反馈修改截图或描述
  - [ ] 重新提交审查

---

## 🎯 立即行动

### 现在就可以做的事情：

1️⃣ **在 Xcode 中运行应用**
```bash
cd /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore
open SeeNews.xcworkspace
# 选择 iPhone 14 Pro 模拟器 → 点击 ▶️ Run
```

2️⃣ **获取截图**
- 按照 `APPSTORE_SCREENSHOTS_GUIDE.md` 的说明
- 或运行快速脚本:
```bash
bash /Users/sundata/WorkBuddy/20260412212940/SeeNewsCore/prepare-appstore-screenshots.sh
```

3️⃣ **准备审查备注**
- 内容已在 `APPSTORE_REVIEW_NOTES.md` 中
- 复制日语版本内容

### 在 App Store Connect 中立即做的事情：

1. 上传审查截图到 Pro Monthly 产品
2. 填写审查备注（复制模板内容）
3. 确保所有元数据显示为"完成 ✓"

---

## 📊 状态总结

```
当前状态: 🟡 元数据 50% 完成
目标状态: 🟢 准备提交

待完成:
  - ⏳ 审查截图 (1-2 小时)
  - ⏳ App Store Connect 上传 (30 分钟)
  - ⏳ 应用版本关联 (30 分钟)
  - ⏳ 提交审查 (10 分钟)

预期完成: 📅 今天内完成
```

---

## 📁 相关文件

| 文件 | 目的 |
|------|------|
| `APPSTORE_SCREENSHOTS_GUIDE.md` | 详细的截图拍摄指南 |
| `APPSTORE_REVIEW_NOTES.md` | 审查备注模板和拒绝处理 |
| `IAP_QUICKREF.md` | App Store Connect 快速参考 |
| `prepare-appstore-screenshots.sh` | 交互式截图准备脚本 |
| `IAP_NOTIFICATIONS_GUIDE.md` | 推送通知配置（已完成）|
| `FIREBASE_QUICKREF.md` | Firebase 配置快速参考 |

---

## ⏱️ 预期时间表

| 任务 | 时间 | 对累计时间 |
|------|------|-----------|
| 在 Xcode 中运行应用 | 5 分钟 | 5 分钟 |
| 拍摄 3 张截图 | 15 分钟 | 20 分钟 |
| 整理截图文件 | 5 分钟 | 25 分钟 |
| 在 App Store Connect 上传 | 10 分钟 | 35 分钟 |
| 填写审查备注 | 5 分钟 | 40 分钟 |
| 更新应用版本 | 10 分钟 | 50 分钟 |
| 上传二进制文件 | 10 分钟 | 60 分钟 |
| 关联订阅と提交 | 10 分钟 | 70 分钟 |
| **总计** | **70 分钟** | **✅ 完成** |
| Apple 审查 | 1-24 小时 | **⏳ 等待** |

---

## ✅ 成功标志

当你看到以下信息时，说明一切就绪：

- ✅ App Store Connect 显示: "ステータス: 準備完了"
- ✅ 应用版本显示: "In review" 或 "Ready for review"
- ✅ 收到来自 Apple 的确认邮件

---

## 🆘 遇到问题？

| 问题 | 解决方案 |
|------|---------|
| "Received 0 products" | 确保产品在 App Store Connect 中状态正是"Ready for Sale" |
| 截图上传失败 | 检查分辨率 (1242x2688px) 和格式 (PNG/JPG) |
| 审查被拒 | 参考 `APPSTORE_REVIEW_NOTES.md` 的拒绝原因部分 |
| Xcode 编译错误 | 运行 `xcode-select --install` 或更新 Xcode |
| 二进制文件上传超时 | 确保网络连接稳定，重试上传 |

---

## 🚀 下一步

1. ✅ 完成本检查清单的所有任务
2. ⏳ 等待 Apple 审查（1-24 小时）
3. 📈 一旦批准，监控订阅：
   - 订阅用户数量
   - 月度经常性收入 (MRR)
   - 取消率

---

## 📞 获取帮助

- 📖 查看相关的 .md 文件获取详细说明
- 🎯 按照此检查清单逐步完成
- ❓ 遇到特定错误时查看"遇到问题"部分

---

**预祝你的 Pro 订阅成功上线！🎉**

开始行动: 立即在 Xcode 中运行应用并拍摄第一张截图！

