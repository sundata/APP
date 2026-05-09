# ID Photo App - App Store 发布准备清单

## ✅ 已完成的配置

### 1. 应用图标
- ✅ 1024×1024 App Store 图标已生成
- ✅ 所有 iOS 标准尺寸图标已生成（20×20 到 180×180）
- ✅ 图标设计：专业级 Midnight Executive + Teal Trust 配色
- ✅ 内容：相机取景框 + 肖像轮廓 + 金色点缀

### 2. 启动画面
- ✅ LaunchScreen.storyboard 已配置
- ✅ 7 种不同尺寸的启动画面已生成
- ✅ 设计与图标风格统一
- ✅ 支持所有 iPhone 和 iPad 尺寸

### 3. 权限配置
- ✅ NSCameraUsageDescription - 相机权限
- ✅ NSPhotoLibraryUsageDescription - 相册读取权限
- ✅ NSPhotoLibraryAddUsageDescription - 相册写入权限
- ✅ NSFaceIDUsageDescription - Face ID 权限（可选）

### 4. 应用元数据
- ✅ 应用名称：証明写真（日文）
- ✅ Bundle Identifier：$(PRODUCT_BUNDLE_IDENTIFIER)
- ✅ 版本号：1.0 (MARKETING_VERSION)
- ✅ Build 号：1 (CURRENT_PROJECT_VERSION)

### 5. 技术配置
- ✅ ITSAppUsesNonExemptEncryption = false（无需加密导出合规）
- ✅ NSAppTransportSecurity 配置（禁用任意加载）
- ✅ 支持的界面方向：仅竖屏
- ✅ UIUserInterfaceStyle = Light（浅色主题）
- ✅ 最低 iOS 版本：iOS 15.0+（Vision AI 要求）

---

## 📋 App Store 提交前检查清单

### 1. App Store Connect 信息准备

#### 应用基本信息
- [ ] **应用名称**：ID Photo / 証明写真
- [ ] **副标题**：证件照专业制作
- [ ] **类别**：摄影 或 效率
- [ ] **年龄分级**：4+

#### 应用描述（需要准备多语言）
- [ ] **日文描述**：
  > 証明写真をスマホで簡単に作成できるアプリです。
  >
  > 主な機能：
  > • アカメラで撮影またはフォトライブラリから選択
  > • 様々なサイズの証明写真に対応
  > • 美肌補正・明るさ調整
  > • 背景色を自由に変更
  > • AI背景除去機能
  > • 高品質で保存・共有
  >
  > パスポート、運転免許証、履歴書など、様々な場面で使用できる証明写真を簡単に作成できます。
  >
  > Vision AI技術を使用して、プロレベルの品質を実現しています。
  >
  > ダウンロードして、すぐに証明写真を作成しましょう！

- [ ] **英文描述**：
  > Create professional ID photos right from your iPhone.
  >
  > Key Features:
  > • Take photos with camera or select from photo library
  > • Support for various ID photo sizes
  > • Beauty correction and brightness adjustment
  > • Customize background colors
  > • AI background removal
  > • High-quality save and share
  >
  > Perfect for passports, driver's licenses, resumes, and more.
  >
  > Powered by Vision AI technology for professional-quality results.
  >
  > Download now and create your ID photos in seconds!

- [ ] **中文描述**：
  > 用手机轻松制作专业证件照。
  >
  > 主要功能：
  > • 相机拍摄或从相册选择
  > • 支持多种证件照尺寸
  > • 美颜补正和亮度调整
  > • 自定义背景颜色
  > • AI背景去除功能
  > • 高质量保存和分享
  >
  > 适用于护照、驾驶证、简历等各种场合的证件照制作。
  >
  > 采用 Vision AI 技术，实现专业级品质。
  >
  > 立即下载，几秒钟内制作你的证件照！

#### 关键词（多语言）
- [ ] **日文关键词**：証明写真, パスポート写真, 履歴書写真, 顔写真, 写真編集, 美肌, 背景
- [ ] **英文关键词**：ID photo, passport photo, resume photo, profile picture, photo editor, beauty, background
- [ ] **中文关键词**：证件照, 护照照片, 简历照片, 头像, 照片编辑, 美颜, 背景

#### 支持网址
- [ ] **技术支持**：https://github.com/yourusername/idphoto-app
- [ ] **营销网址**：（可选）
- [ ] **隐私政策**：需要创建隐私政策页面

#### 隐私政策
- [ ] 创建隐私政策页面（必须）
  - 说明收集哪些数据
  - 说明数据如何使用
  - 说明第三方服务使用（Vision AI）
  - 提供联系方式

### 2. 屏幕截图（需要准备）

#### iPhone 截图要求
- [ ] 6.7" 显示屏截图（1290×2796）- 必需
- [ ] 6.5" 显示屏截图（1242×2688）- 必需
- [ ] 5.5" 显示屏截图（1242×2208）- 可选

#### 推荐截图内容（每个尺寸 3-10 张）
1. **首页**：展示主界面和应用名称
2. **拍照功能**：展示相机界面
3. **尺寸选择**：展示支持的证件照尺寸
4. **编辑功能**：展示裁剪、美颜等功能
5. **背景选择**：展示背景颜色选项
6. **AI背景去除**：展示AI功能
7. **保存/分享**：展示导出选项
8. **完成效果**：展示最终效果

#### iPad 截图（如果支持）
- [ ] 12.9" 显示屏截图（2048×2732）- 可选
- [ ] 11" 显示屏截图（1668×2388）- 可选

### 3. App Store 推广素材

#### 应用预告片（可选但推荐）
- [ ] 15-30 秒的应用演示视频
- [ ] 格式：.mov 或 .mp4
- [ ] 分辨率：1920×1080 或更高
- [] 内容：快速展示主要功能

### 4. 审核信息

#### 审核备注
- [ ] 说明应用的主要功能
- [ ] 说明如何测试所有功能
- [ ] 提供测试账号（如果有）
- [ ] 说明使用的第三方技术（Vision AI）

#### 联系信息
- [ ] **姓名**：你的名字
- [ ] **邮箱**：your.email@example.com
- [ ] **电话**：+81 XX XXXX XXXX（可选）

---

## 🔧 技术检查清单

### 代码质量
- [ ] 所有警告已修复
- [ ] 构建成功，无错误
- [ ] 测试了所有主要功能
- [ ] 内存泄漏已检查
- [ ] 崩溃率低

### 性能
- [ ] 启动时间 < 3 秒
- [ ] 应用响应流畅
- [ ] 无明显卡顿
- [ ] 电池使用合理

### 用户体验
- [ ] 所有界面适配各种屏幕尺寸
- [ ] 文字清晰可读
- [ ] 按钮足够大，易于点击
- [ ] 支持暗黑模式（如果支持）
- [ ] 支持动态字体（如果支持）

### 权限
- [ ] 所有权限都有清晰的说明
- [ ] 权限请求时机合理
- [ ] 拒绝权限后应用仍可正常使用部分功能

### 本地化
- [ ] 所有用户界面文本已本地化
- [ ] 日文、英文、中文版本
- [ ] 错误消息已本地化
- [ ] 权限说明已本地化

---

## 📊 版本发布策略

### 初始发布 (Version 1.0)
**发布日期**：计划在 [填写日期]

**主要功能**：
- ✅ 照片拍摄和选择
- ✅ 多种证件照尺寸支持
- ✅ 裁剪和旋转
- ✅ 美颜补正
- ✅ 背景颜色选择
- ✅ AI背景去除
- ✅ 保存到相册
- ✅ 分享功能

**目标受众**：
- 需要制作证件照的个人用户
- 求职者（简历照片）
- 旅行者（护照照片）
- 学生（各种申请照片）

**定价策略**：
- [ ] 免费下载
- [ ] 内购选项（可选）
  - AI背景去除：$0.99
  - 高级美颜滤镜：$1.99
  - 去广告：$1.99

---

## 📝 发布前最后检查

### App Store Connect
- [ ] 创建应用记录
- [ ] 上传图标
- [ ] 上传截图
- [ ] 填写所有元数据
- [ ] 上传构建版本
- [ ] 提交审核

### 测试
- [ ] 在真机上测试所有功能
- [ ] 测试不同 iOS 版本（iOS 15, 16, 17）
- [ ] 测试不同设备（iPhone SE, 12, 13, 14, 15）
- [ ] 测试 iPad（如果支持）
- [ ] 测试各种场景（弱网、低电量、后台切换）

### 合规性
- [ ] 符合 Apple 审核指南
- [ ] 符合当地法律法规
- [ ] 隐私政策完整
- [ ] 无侵权内容
- [ ] 无误导性描述

---

## 🚀 发布步骤

### 1. 准备阶段（1周前）
- [ ] 完成所有功能开发和测试
- [ ] 准备所有截图和素材
- [ ] 编写应用描述和关键词
- [ ] 创建隐私政策页面

### 2. 提交阶段
- [ ] 在 App Store Connect 创建应用
- [ ] 填写所有必填信息
- [ ] 上传截图和图标
- [ ] 创建并上传构建版本
- [ ] 提交审核

### 3. 审核阶段（1-2天）
- [ ] 等待 Apple 审核
- [ ] 准备回答审核问题
- [ ] 如需修改，及时响应

### 4. 发布阶段
- [ ] 审核通过后选择发布时间
- [ ] 准备发布公告
- [ ] 准备营销材料
- [ ] 监控用户反馈

---

## 📞 支持资源

### Apple 开发者资源
- [App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect 帮助](https://help.apple.com/app-store-connect/)

### 开发者论坛
- [Apple 开发者论坛](https://developer.apple.com/forums/)

### 工具
- [TestFlight](https://help.apple.com/app-store-connect/#/devdc3e586d) - Beta 测试
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi) - 自动化

---

## 📈 发布后

### 监控
- [ ] 下载量统计
- [ ] 用户评分和评论
- [ ] 崩溃报告
- [ ] 性能指标

### 迭代
- [ ] 收集用户反馈
- [ ] 规划下一个版本
- [ ] 修复发现的问题
- [ ] 添加新功能

---

**最后更新日期**：2026年3月17日
**文档版本**：1.0
