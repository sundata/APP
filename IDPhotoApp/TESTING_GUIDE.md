# iPhone 15 启动问题测试指南

## 当前状态

✅ 代码已修复
✅ 构建成功（BUILD SUCCEEDED）
✅ 已部署到 iPhone 15 (SunData)

## 问题
iPhone 15 上启动后一直显示启动画面，无法切换到主界面。

## 修复内容

### 1. 延迟初始化服务
```swift
class PhotoEditorViewModel: ObservableObject {
    lazy var imageService = ImageService()
    private lazy var beautyService = BeautyService()
    private lazy var backgroundService = BackgroundService()
    lazy var exportService = ExportService()
}
```

### 2. 延迟初始化 CIContext
```swift
class BackgroundService {
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])
}
```

### 3. 添加调试输出
- `IDPhotoAppApp.init()`: 打印 "🚀 IDPhotoAppApp init"
- `ContentView.onAppear`: 打印 "✅ ContentView appeared"
- `HomeView.onAppear`: 打印 "✅ HomeView.onAppear"

## 测试步骤

### 步骤 1：完全关闭应用
1. 从 iPhone 15 上双击 Home 键（或上滑）
2. 找到 IDPhotoApp
3. 上滑关闭应用
4. 确保完全退出

### 步骤 2：连接到 Mac
1. 使用 Lightning 线连接 iPhone 15 到 Mac
2. 打开 Xcode
3. Window → Devices and Simulators
4. 选择你的 iPhone (SunData)
5. 点击 "View Device Logs"

### 步骤 3：启动应用
1. 在 iPhone 15 上点击 IDPhotoApp 图标
2. 观察屏幕：
   - 应该看到深蓝色背景的启动画面
   - 显示 "ID Photo" 文字
   - 显示金色 Loading 指示器

### 步骤 4：等待 5 秒
- 启动画面应该显示 1-3 秒
- 然后自动消失
- 主界面应该出现

### 步骤 5：观察结果

#### 情况 A：正常工作 ✅
- 启动画面显示 1-3 秒
- 自动消失
- 主界面显示（浅灰色背景 + "証明写真" + 按钮）
- **问题解决！**

#### 情况 B：还是卡住 ❌
- 启动画面一直显示
- 5 秒后还是启动画面
- 需要进一步调查

### 步骤 6：查看日志（如果卡住）

#### 在 Xcode 中查看日志：
1. Xcode → Window → Devices and Simulators
2. 选择你的 iPhone
3. 点击 "View Device Logs"
4. 选择 IDPhotoApp 进程
5. 查找以下日志：

```
🚀 IDPhotoAppApp init - App is starting...
✅ ContentView appeared - Main UI is visible!
✅ ContentView.onAppear - HomeView is loading...
✅ HomeView.onAppear - UI is visible!
```

#### 日志分析：

**如果只看到 `🚀 IDPhotoAppApp init`**：
- 应用在初始化 `PhotoEditorViewModel` 时卡住
- 可能还有其他耗时操作

**如果看到所有日志**：
- 应用正常启动
- 问题可能是视觉混淆（启动画面和主界面背景相似）

**如果没有任何日志**：
- 应用可能崩溃
- 检查是否有错误信息

### 步骤 7：强制重启（如果卡住）

```bash
# 1. 从 iPhone 上删除应用
# - 长按应用图标
# - 点击 "删除 App"
# - 确认删除

# 2. 重新安装
# 在 Xcode 中：
# - Product → Run
# - 或按 ⌘R

# 3. 重新启动应用
# - 点击应用图标
# - 观察启动画面
```

## 可能的原因和解决方案

### 原因 1：还有其他耗时操作

**检查是否有以下操作**：
- 网络请求
- 文件读写
- 数据库初始化
- 第三方 SDK 初始化

**解决方案**：
- 将耗时操作移到后台线程
- 使用延迟加载
- 异步初始化

### 原因 2：视觉混淆

**现象**：
- 启动画面和主界面背景颜色相似
- 用户误以为还是启动画面

**解决方案**：
- 改变主界面背景颜色
- 添加明显的动画
- 添加 Loading 指示器

### 原因 3：LaunchScreen.storyboard 配置错误

**检查**：
- `UILaunchStoryboardName` 是否正确
- Storyboard 是否有效
- 是否有引用不存在的资源

**解决方案**：
- 重新创建 LaunchScreen.storyboard
- 移除所有图片引用
- 使用纯色背景

## 下一步

### 如果问题解决：
✅ 太好了！应用可以正常启动了

### 如果问题未解决：

#### 方案 1：创建最小可复现示例
1. 创建一个新的空白项目
2. 只添加基本的 UI
3. 测试启动画面
4. 逐步添加功能，找出问题

#### 方案 2：联系 Apple 开发者支持
- 提供项目文件
- 提供日志信息
- 提供复现步骤

#### 方案 3：使用 Xcode Instruments
1. Product → Profile
2. 选择 "Time Profiler"
3. 运行应用
4. 查看耗时操作

## 调试技巧

### 使用断点
```swift
@main
struct IDPhotoAppApp: App {
    init() {
        print("🚀 IDPhotoAppApp init")  // 在这里设置断点
    }
}
```

### 使用 Instruments
1. Xcode → Product → Profile
2. 选择 "Time Profiler"
3. 运行应用
4. 查看哪些函数耗时最长

### 使用 Console.app
1. 打开 Console.app
2. 选择你的 iPhone
3. 搜索 "IDPhotoApp"
4. 查看所有日志

## 总结

### 已完成的修复：
✅ 延迟初始化服务对象
✅ 延迟初始化 CIContext
✅ 添加调试输出
✅ 优化 LaunchScreen.storyboard
✅ 构建成功

### 需要用户测试：
🔄 在 iPhone 15 上启动应用
🔄 观察启动画面和主界面的切换
🔄 查看日志输出
🔄 报告结果

### 预期结果：
- 启动画面显示 1-3 秒
- 自动消失
- 主界面正常显示
- 所有功能正常工作

**请在 iPhone 15 上测试并告诉我结果！** 🎉
