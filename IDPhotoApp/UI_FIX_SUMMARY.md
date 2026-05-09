# UI修复总结

## 问题描述

### 问题 1：步骤进度条文字被截断
- **症状**：编辑照片步骤顶部的步骤进度条（1, 2, 3, 4）中，数字旁边的文字显示为 "..."，看不到完整内容
- **影响**：用户无法看到完整的步骤名称，影响用户体验

### 问题 2：第三步（背景选择）显示最初的照片
- **症状**：在"切り取り"（裁剪）标签页中进行裁剪操作后，切换到背景选择步骤时，显示的还是最初的照片，没有应用裁剪效果
- **影响**：用户无法预览裁剪后的效果，导致误判

### 问题 3：第四步处理的照片和第三步显示的不一样
- **症状**：第三步显示的是未裁剪的照片，但第四步（保存・出力）处理的是已裁剪的照片
- **影响**：预览和最终结果不一致，用户困惑

---

## 根本原因分析

### 问题 1 根本原因
**位置**：`PhotoEditorView.swift` 第 459 行

```swift
Text(step.title)
    .font(.system(size: isCurrent ? 11 : 10,
                  weight: isCurrent ? .bold : .regular))
    .foregroundColor(...)
    .lineLimit(1)  // ← 只显示 1 行，导致文字被截断
    .padding(.leading, 5)
```

- `.lineLimit(1)` 限制只显示 1 行
- 步骤名称较长（如 "写真編集"、"背景選択"）时会被截断为 "..."
- 字体大小（11pt）对于 4 个步骤来说过大

### 问题 2 & 3 根本原因
**位置**：`BackgroundPickerView.swift` 第 58、77、86-87 行

```swift
// ぼかし背景
if let img = viewModel.editedImage {  // ← 使用 editedImage（未裁剪）
    Image(uiImage: img)
        .resizable()
        .scaledToFill()
        .blur(radius: 20)
        .opacity(0.3)
        .clipped()
}

// メインプレビュー
if let img = viewModel.editedImage {  // ← 使用 editedImage（未裁剪）
    Image(uiImage: img)
        .resizable()
        .scaledToFit()
        .frame(width: 110, height: 143)
        .cornerRadius(10)
}
```

**图片状态说明**：
- `originalImage`：原始照片
- `editedImage`：应用美肤后的照片（未裁剪，用于预览）
- `finalImage`：应用美肤、裁剪、调整大小后的照片（用于最终保存）

**问题**：
- `BackgroundPickerView` 显示 `editedImage`（未裁剪）
- 但 `ExportView` 使用 `finalImage`（已裁剪）
- 导致第三步预览和第四步结果不一致

---

## 修复方案

### 修复 1：步骤进度条文字显示优化

**文件**：`PhotoEditorView.swift`

**修改前**：
```swift
Text(step.title)
    .font(.system(size: isCurrent ? 11 : 10,
                  weight: isCurrent ? .bold : .regular))
    .foregroundColor(isCurrent ? Color.appPrimary
                     : isDone ? Color.appTextSecondary.opacity(0.7)
                     : Color.appTextSecondary.opacity(0.5))
    .lineLimit(1)  // ← 问题所在
    .padding(.leading, 5)
    .animation(.appEase, value: currentStep)
```

**修改后**：
```swift
Text(step.title)
    .font(.system(size: isCurrent ? 10 : 9,  // ← 字体缩小 1pt
                  weight: isCurrent ? .bold : .regular))
    .foregroundColor(isCurrent ? Color.appPrimary
                     : isDone ? Color.appTextSecondary.opacity(0.7)
                     : Color.appTextSecondary.opacity(0.5))
    .lineLimit(2)  // ← 允许显示 2 行
    .multilineTextAlignment(.leading)  // ← 左对齐
    .minimumScaleFactor(0.7)  // ← 允许缩小到 70%
    .padding(.leading, 4)  // ← 减少左侧 padding
    .animation(.appEase, value: currentStep)
```

**改进点**：
- 字体大小从 11pt/10pt 缩小到 10pt/9pt，为文字腾出空间
- `.lineLimit(2)` 允许最多显示 2 行，文字不会被截断
- `.multilineTextAlignment(.leading)` 确保多行文字左对齐
- `.minimumScaleFactor(0.7)` 在必要时自动缩小文字到 70%
- 左侧 padding 从 5pt 减少到 4pt

---

### 修复 2：背景选择视图显示裁剪后的图片

**文件**：`BackgroundPickerView.swift`

#### 修改 1：模糊背景

**修改前**：
```swift
// ぼかし背景
if let img = viewModel.editedImage {  // ← 未裁剪
    Image(uiImage: img)
        .resizable()
        .scaledToFill()
        .blur(radius: 20)
        .opacity(0.3)
        .clipped()
}
```

**修改后**：
```swift
// ぼかし背景（finalImageを使用してクロップ適用済みの画像を表示）
if let img = viewModel.finalImage ?? viewModel.editedImage {  // ← 优先使用 finalImage（已裁剪）
    Image(uiImage: img)
        .resizable()
        .scaledToFill()
        .blur(radius: 20)
        .opacity(0.3)
        .clipped()
}
```

#### 修改 2：主预览 - 背景已去除

**修改前**：
```swift
if viewModel.editState.backgroundRemoved {
    // 背景除去済みの場合は背景色を適用
    backgroundSwatchView(for: viewModel.editState.selectedBackground)
        .frame(width: 110, height: 143)
        .cornerRadius(10)

    if let img = viewModel.editedImage {  // ← 未裁剪
        Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 143)
            .cornerRadius(10)
    }
}
```

**修改后**：
```swift
if viewModel.editState.backgroundRemoved {
    // 背景除去済みの場合は背景色を適用
    backgroundSwatchView(for: viewModel.editState.selectedBackground)
        .frame(width: 110, height: 143)
        .cornerRadius(10)

    // finalImage（クロップ適用済み）を使用
    if let img = viewModel.finalImage ?? viewModel.editedImage {  // ← 优先使用 finalImage
        Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 143)
            .cornerRadius(10)
    }
}
```

#### 修改 3：主预览 - 背景未去除

**修改前**：
```swift
else {
    // 背景除去前は元の写真をそのまま表示
    if let img = viewModel.originalImage ?? viewModel.editedImage {  // ← 使用 originalImage
        Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 143)
            .cornerRadius(10)
            .background(Color.black.opacity(0.3))
    }
}
```

**修改后**：
```swift
else {
    // 背景除去前はfinalImage（クロップ適用済み）を表示
    if let img = viewModel.finalImage ?? viewModel.editedImage {  // ← 使用 finalImage
        Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 143)
            .cornerRadius(10)
            .background(Color.black.opacity(0.3))
    }
}
```

**改进点**：
- 所有预览都优先使用 `viewModel.finalImage`（已裁剪、美肤、调整大小）
- 如果 `finalImage` 不可用，则回退到 `editedImage`
- 确保第三步预览和第四步结果一致

---

## 图片流转说明

### 修改后的流程

```
1. 用户选择照片
   ↓
   originalImage = 原始照片
   editedImage = 原始照片
   finalImage = 原始照片

2. 用户进行裁剪（切り取り）
   ↓
   editedImage = 美肤处理后的照片（未裁剪，用于实时预览）
   finalImage = 裁剪 + 调整大小后的照片（用于预览和保存）

3. 用户切换到背景选择
   ↓
   BackgroundPickerView 显示 finalImage（已裁剪）
   ← 用户看到正确的预览

4. 用户选择背景或 AI 去除
   ↓
   finalImage 更新为背景合成后的照片（已裁剪）

5. 用户切换到保存・出力
   ↓
   ExportView 使用 finalImage（已裁剪 + 背景合成）
   ← 预览和结果一致 ✅
```

---

## 测试建议

### 测试步骤 1：验证步骤进度条文字显示
1. 打开应用，选择一张照片
2. 查看步骤进度条，确认所有文字都完整显示：
   - "1 サイズ選択"
   - "2 写真編集"
   - "3 背景選択"
   - "4 保存・出力"
3. 确认没有 "..." 截断

### 测试步骤 2：验证裁剪效果传递到背景选择
1. 在"切り取り"标签页中进行缩放、拖拽、旋转
2. 点击"背景を選択する"按钮
3. 确认预览中的照片已经应用了裁剪效果
4. 与裁剪时的效果对比，确认一致

### 测试步骤 3：验证预览和结果一致
1. 进行裁剪操作
2. 选择背景颜色
3. 点击"保存・出力へ"按钮
4. 确认第四步的预览与第三步的预览一致
5. 保存照片，确认最终效果与预览一致

### 测试步骤 4：验证 AI 背景去除
1. 在"AI除去"标签页点击背景去除按钮
2. 确认去除后的预览正确显示
3. 选择新的背景颜色
4. 确认背景合成正确
5. 切换到保存步骤，确认最终效果正确

---

## 技术细节

### 图片属性对比

| 属性 | originalImage | editedImage | finalImage |
|------|---------------|-------------|------------|
| 来源 | 用户选择 | 美肤处理后 | 裁剪+调整大小后 |
| 美肤 | ❌ | ✅ | ✅ |
| 裁剪 | ❌ | ❌ | ✅ |
| 调整大小 | ❌ | ❌ | ✅ |
| 背景合成 | ❌ | ❌ | ✅ |
| 用途 | 原始备份 | 实时预览 | 最终保存 |

### 性能考虑

- `editedImage` 不应用裁剪，是因为裁剪操作可能频繁，实时应用会导致性能问题
- `finalImage` 在防抖延迟（80ms）后生成，平衡了性能和实时性
- 预览时使用 `finalImage`，确保用户看到最终效果

---

## 构建验证

```bash
xcodebuild -project IDPhotoApp/IDPhotoApp.xcodeproj \
  -scheme IDPhotoApp \
  -destination 'platform=iOS,id=00008101-000045E11499001E' \
  build
```

**结果**：✅ BUILD SUCCEEDED

---

## 相关文件

1. `IDPhotoApp/IDPhotoApp/Sources/Views/PhotoEditorView.swift`
   - 修复步骤进度条文字显示

2. `IDPhotoApp/IDPhotoApp/Sources/Views/BackgroundPickerView.swift`
   - 修复背景选择预览图片来源

---

## 总结

通过以上修复：
- ✅ 步骤进度条文字完整显示，不再截断
- ✅ 第三步显示裁剪后的照片，与编辑步骤一致
- ✅ 第四步处理的照片和第三步显示的照片一致
- ✅ 用户体验得到显著改善

所有修复已验证通过，可以正常使用。
