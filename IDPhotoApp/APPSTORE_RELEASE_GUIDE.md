# App Store 发布指南

## 项目信息
- Bundle ID: com.idphoto.japan
- Team ID: HQ9A6C8C3R (jianwei chen)
- 版本: 1.0 (Build 1)
- Archive: /Users/sundata/WorkBuddy/20260313120252/IDPhotoApp/build/IDPhotoApp.xcarchive ✅

---

## 步骤一：在 App Store Connect 创建 App

1. 打开 https://appstoreconnect.apple.com
2. 点击「我的 App」→「+」→「新建 App」
3. 填写信息：

| 字段 | 填写内容 |
|------|---------|
| 平台 | iOS |
| 名称 | 証明写真 |
| 主要语言 | 日语 |
| Bundle ID | com.idphoto.japan（需要先在 Developer 门户创建）|
| SKU | idphoto-japan-001 |

---

## 步骤二：在 Apple Developer 门户创建 App ID 和 Profile

如果 Bundle ID 还未注册：

1. 打开 https://developer.apple.com/account
2. Certificates, IDs & Profiles → Identifiers → +
3. 选择 App IDs → App
4. Description: IDPhotoJapan
5. Bundle ID（Explicit）: com.idphoto.japan
6. Capabilities 按需勾选（Photos Library、Camera 等）
7. 创建后，生成 Distribution Provisioning Profile：
   - Provisioning Profiles → +
   - App Store Connect
   - 选择刚创建的 App ID
   - 选择 Distribution 证书
   - 命名并下载

---

## 步骤三：在 Xcode 中上传（推荐方法）

### 方法 A：Organizer 上传（最简单）

```bash
# Archive 已经生成：
open /Users/sundata/WorkBuddy/20260313120252/IDPhotoApp/build/IDPhotoApp.xcarchive
```

或者在 Xcode 中：
1. **Xcode → Window → Organizer**（⌘⇧O）
2. 左侧选择 IDPhotoApp 的 Archive
3. 点击右侧「**Distribute App**」
4. 选择「**App Store Connect**」→ Next
5. 选择「**Upload**」→ Next
6. 勾选：
   - ✅ Include bitcode for iOS content
   - ✅ Upload your app's symbols
7. 选择「**Automatically manage signing**」→ Next
8. 等待验证和上传（约 2-5 分钟）

### 方法 B：命令行上传（需要 App-Specific Password）

```bash
# 1. 生成 App-Specific Password
# 访问 https://appleid.apple.com → 安全 → 生成 App 专用密码

# 2. 上传 IPA
xcrun altool --upload-app \
  --type ios \
  --file /Users/sundata/WorkBuddy/20260313120252/IDPhotoApp/build/export/IDPhotoApp.ipa \
  --username "your-apple-id@email.com" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

---

## 步骤四：填写 App Store 信息

上传成功后，在 App Store Connect 中填写：

### 基本信息
| 字段 | 内容 |
|------|------|
| 名称 | 証明写真 - ID Photo Maker |
| 副标题 | プロ品質の証明写真をスマホで |
| 类别 | 主类别：照片与摄像（Photography）|
| 价格 | 免费（Free）|

### 描述（日文）
```
📸 プロ品質の証明写真を、今すぐスマホで作成！

【主な機能】
✅ 14種類以上の証明写真サイズに対応
   パスポート・マイナンバー・履歴書・運転免許など

✅ AI背景除去
   ワンタップで背景を自動削除、好きな色に変更

✅ 高精度な美肌補正
   明るさ・コントラスト・色温度をカスタマイズ

✅ 写真トリミング
   ピンチ・ドラッグで正確な構図調整、回転・反転も

✅ 高解像度エクスポート
   証明写真として使える高品質JPEGで保存

【対応サイズ】
・パスポート (35×45mm)
・マイナンバー (35×45mm)  
・履歴書 (30×40mm)
・運転免許 (24×30mm)
・その他 10種類以上

【使い方】
1. 写真を撮影またはライブラリから選択
2. サイズを選択
3. 明るさ・美肌などを調整
4. 背景を選択（白・青・その他）
5. 保存・出力

プロのカメラマンに頼まなくても、自宅でいつでも証明写真が作れます！
```

### 描述（中文，备用）
```
📸 用手机制作专业证件照！

【主要功能】
✅ 支持14种以上证件照尺寸
✅ AI智能背景去除
✅ 美颜调整（亮度/对比度/色温）
✅ 精准裁剪和旋转
✅ 高分辨率导出

【支持尺寸】
护照、身份证、驾照、简历照等14种规格

操作简单，1分钟完成专业证件照！
```

### 关键词（日文，最多100字符）
```
証明写真,パスポート写真,マイナンバー,履歴書,ID Photo,background removal,AI,美肌
```

### App 审核信息
| 字段 | 内容 |
|------|------|
| 测试账号 | 不需要（无登录功能）|
| 备注 | 此 App 需要相机和相册访问权限来拍摄和选择照片 |

---

## 步骤五：截图准备

需要准备以下截图（每种设备至少1张，最多10张）：

### iPhone 6.9"（iPhone 16 Pro Max / 必须提供）
分辨率：1320×2868 px

### iPhone 6.7"（iPhone 15 Plus，可选）
分辨率：1290×2796 px

### iPad Pro 13"（如果支持 iPad）
分辨率：2064×2752 px

### 截图建议：
1. 主页（证明写真 标题 + 操作按钮）
2. 选择照片后的编辑页面
3. 美肤调整界面
4. AI 背景去除效果对比
5. 导出/保存界面

---

## 步骤六：提交审核

1. 在 App Store Connect 确认所有必填字段已填写
2. 上传截图
3. 点击「**Add for Review**」
4. 选择「**Submit to App Review**」

**审核时间**：通常 24-48 小时

---

## 当前状态

| 项目 | 状态 |
|------|------|
| Bundle ID | com.idphoto.japan |
| Distribution 证书 | ✅ 有效 (HQ9A6C8C3R) |
| Archive | ✅ 已生成 |
| App Store Connect App | ❓ 需要确认是否已创建 |
| Provisioning Profile | ❌ 需要创建 App Store 类型的 |
| 截图 | ❓ 需要准备 |

---

## 快速上传命令（Archive 已就绪）

打开 Xcode Organizer：
```bash
open /Users/sundata/WorkBuddy/20260313120252/IDPhotoApp/build/IDPhotoApp.xcarchive
```

这会直接打开 Xcode 的 Organizer，显示该 Archive，然后点击「Distribute App」即可完成上传。
