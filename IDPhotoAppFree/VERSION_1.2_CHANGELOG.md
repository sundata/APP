# IDPhotoAppFree v1.2 发布内容汇总

## 版本信息
- **MARKETING_VERSION**: 1.1 → **1.2**
- **CURRENT_PROJECT_VERSION**: 2 → **3**

---

## 一、代码修复（功能 Bug 修复）

### 1-1. 工具栏按钮显示异常（App Store 审查）
- **问题**: 底部工具栏只显示 3 个按钮，「保存」按钮缺失
- **原因**: `.frame(maxWidth: .infinity)` 导致 Flex 布局崩溃
- **修复**: 各按钮改为 `.frame(minWidth: 60)`，5 个按钮全部正常显示
- **文件**: `PhotoEditorView.swift`

### 1-2. 回転按钮无效
- **问题**: 点击旋转按钮，照片预览不旋转
- **原因**: 预览图片未应用 `.rotationEffect()`
- **修复**: 添加 `.rotationEffect(.degrees(viewModel.editState.cropState.rotation))`
- **文件**: `PhotoEditorView.swift`

### 1-3. 保存按钮不跳转
- **问题**: 点击「保存」按钮无反应
- **原因**: `advanceToExport()` 方法有多个条件分支，逻辑中断
- **修复**: 简化为直接执行 `viewModel.currentStep = .export`
- **文件**: `PhotoEditorView.swift`

### 1-4. 导出页面无返回按钮
- **问题**: 导出页面无法返回编辑画面
- **修复**: `ExportView` 外层包裹 `ZStack`，左上角叠加「編集に戻る」按钮
- **文件**: `ExportView.swift`

### 1-5. LaunchScreen 资源分配警告
- **问题**: LaunchScreen.imageset 的 4 张图片显示「unassigned」
- **原因**: iPhone 12 Pro Max 之后的屏幕尺寸（2532/2556/2688/2778）缺少 `subtype` 声明
- **修复**: `Contents.json` 中为每张图片添加对应的 `subtype` 字段
- **文件**: `Assets.xcassets/LaunchScreen.imageset/Contents.json`

---

## 二、App Store 上架错误修复

### 2-1. iPad 多任务方向支持不足
- **错误**: Validation failed — iPad 必须支持全部 4 个方向
- **修复**: Info.plist 新增 `UISupportedInterfaceOrientations~ipad`，声明全方向
- **文件**: `Info.plist`

### 2-2. Build 版本 Train 已关闭
- **错误**: `Invalid Pre-Release Train. The train version '1.0' is closed`
- **修复**: 版本号升至 1.2 / Build 号升至 3
- **文件**: `project.pbxproj`

### 2-3. dSYM 符号文件缺失
- **错误**: `The archive did not include a dSYM for the GoogleMobileAds.framework`
- **原因**: GoogleMobileAds/UserMessagingPlatform 通过 SPM 下载，dSYM 不在 Archive 中
- **修复**: 新增 Run Script Build Phase（A8000003），Archive 时自动从 GitHub 下载 dSYM
  - 下载失败时不阻断构建（`|| true` + 脚本末尾统一返回 0）
  - outputPaths 声明 sentinel 文件，实现增量构建跳过
- **SDK**: GoogleMobileAds 11.13.0 / UserMessagingPlatform 2.7.0
- **文件**: `project.pbxproj`

---

## 三、功能增强

### 3-1. 免费版尺寸大幅扩充
| 分类 | 新增内容 |
|------|---------|
| 护照/签证 | 日本、欧州、美国、中国、韩国、英国、加拿大、澳洲 |
| 美国规格 | 2×3英寸、US 护照 |
| 中国/台湾 | 1寸、2寸 |
| 韩国/越南/泰国 | 各国当地规格 |
| 其他 | 学生证、健康保险证、通用 35×45mm |

- 变更前：免费版 8 个尺寸
- 变更后：**免费版 27 个尺寸，全部 `isPro: false`**
- **文件**: `IDPhotoModel.swift`

### 3-2. App Store 截图补充
- 13 英寸 iPad 竖屏（2048×2732px）
- 13 英寸 iPad 横屏（2732×2048px）
- 文件: `screenshots_for_appstore/ipad_13inch_6.5in_appstore.png` / `ipad_13inch_landscape_appstore.png`

---

## 四、v1.2 已完成的 App Store 上架要求

| 项目 | 状态 |
|------|------|
| iPad 多任务方向 | ✅ 已修复 |
| 版本号 1.2 | ✅ 已设置 |
| 13 英寸 iPad 截图 | ✅ 已添加 |
| dSYM 下载脚本 | ✅ 已添加 |
| 功能 Bug 修复 | ✅ 全部完成 |

---

## 五、需要手动在 App Store Connect 填写的内容

**① 「このバージョンの最新情報」**（版本更新说明，日语）：

```
【v1.2 更新内容】
- ツールバー表示を改善：すべてのボタンが正しく表示されるようになりました
- 回転ボタンをタップすると写真が正しく回転するようになりました
- 保存ボタンをタップすると写真出力画面へ正常に遷移するようになりました
- 写真出力画面に「編集に戻る」ボタンを追加しました
- 免费版で対応可能な証明写真サイズを27種類に大幅扩充
- 轻微なバグ修正と动作改善
```

**② 截图上传**：新的 iPad 截图（2048×2732 / 2732×2048）需上传至 App Store Connect

**③ 检查其他元数据**：Keywords、Support URL、Privacy Policy URL 等是否填写完整

---

## 六、有料版（IDPhotoApp）同步更新内容

### 6-1. 预设尺寸同步（27尺寸）
- **变更内容**：与免费版保持一致，`allSizes` 从 17 个扩充至 **27 个**
- **新增**：欧州・米国・中国・韓国・英国・カナダ・澳洲签证规格，以及美国 2×3 英寸、中国 1/2 寸、韩国/越南/泰国规格等
- **文件**: `IDPhotoApp/Sources/Models/IDPhotoModel.swift`

### 6-2. 自定义尺寸功能（有料版独占）
- **新增功能**：有料版用户可在「サイズ選択」页面点击「カスタム」分类标签，输入任意宽高（mm）自定义照片尺寸
- **功能亮点**:
  - 支持宽/高独立输入（1〜200mm）
  - 可自定义尺寸名称
  - 提供常用尺寸快捷预设（中国1寸、4×6cm、50×50mm等）
  - 自定义尺寸自动同步到 CropView 和 ExportView
- **模型变更**: `IDPhotoSize` 新增 `CustomSizeInfo` 结构体，`EditState` 新增 `customSize` 和 `usingCustomSize` 属性
- **文件**: `IDPhotoApp/Sources/Models/IDPhotoModel.swift`, `IDPhotoApp/Sources/ViewModels/PhotoEditorViewModel.swift`, `IDPhotoApp/Sources/Views/SizePickerView.swift`

### 6-3. 预览面板旋转效果修复
- **问题**: 편집画面预览照片旋转后，预览面板未实时更新
- **修复**: `PhotoEditorView` 的 `photoPreviewPanel` 添加 `.rotationEffect(.degrees(viewModel.editState.cropState.rotation))`
- **文件**: `IDPhotoApp/Sources/Views/PhotoEditorView.swift`

### 6-4. 导出页面返回按钮
- **问题**: 有料版 ExportView 没有返回编辑页面的按钮
- **修复**: `ExportView` 外层包裹 `ZStack`，左上角叠加「編集に戻る」按钮
- **文件**: `IDPhotoApp/Sources/Views/ExportView.swift`

### 6-5. 导航栏按钮显示问题（与免费版相同）
- 有料版同样使用不同的 PhotoEditorView 结构，需确认按钮显示正常
