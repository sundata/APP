# わりメモ - Xcodeプロジェクトセットアップ

## 📋 Xcodeプロジェクト作成ステップ

このドキュメントは、SwiftUIのソースコードからXcodeプロジェクトを構築するための手順を説明します。

### ステップ1: Xcodeプロジェクトの作成

```bash
cd ~/Documents/GitHub/APP/わりメモ

# 新しいSwiftUIアプリプロジェクトを作成
# Xcodeで以下の設定で作成：
# - Product Name: わりメモ
# - Team ID: [あなたのTeam ID]
# - Bundle Identifier: com.yourcompany.warimeao
# - Minimum Deployments: iOS 16.0
# - Interface: SwiftUI
# - Life Cycle: SwiftUI App
```

### ステップ2: ソースファイルの配置

既存のソースファイルを以下の場所にコピーします：

```
プロジェクト/
├── わりメモ/
│   ├── WarimemoApp.swift
│   ├── Models/
│   │   └── Group.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── GroupDetailView.swift
│   │   ├── SettlementResultView.swift
│   │   ├── NewGroupSheet.swift
│   │   ├── AddPaymentSheet.swift
│   │   └── AddMemberSheet.swift
│   ├── ViewModels/
│   │   └── GroupManager.swift
│   └── Utils/
│       └── Extensions.swift
```

### ステップ3: Xcode内でファイルを組織する

1. Xcodeを開く
2. Project Navigator (Cmd+1) から右クリック
3. "New Group" でフォルダを作成：
   - Models
   - Views
   - ViewModels
   - Utils

4. ファイルをドラッグして各グループに配置

### ステップ4: ビルド設定

**ビルドフェーズの確認:**

1. Target → Build Phases
2. "Compile Sources" にすべてのSwiftファイルが含まれていることを確認
3. 欠けているファイルがあれば、"+" ボタンで追加

**署名設定:**

1. Target → Signing & Capabilities
2. Team を選択
3. Bundle ID を設定: `com.yourcompany.warimeao`

### ステップ5: Info.plist設定

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ja_JP</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>わりメモ</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIMainStoryboardFile</key>
    <string></string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>This app does not use local network.</string>
</dict>
</plist>
```

### ステップ6: ビルド & 実行

```bash
# シミュレータでビルド・実行
xcodebuild -scheme わりメモ -configuration Debug -sdk iphonesimulator build

# または Xcode内で Cmd+R を押す
```

## 🐛 トラブルシューティング

### ビルドエラー: "WarimemoApp.swift:1:1: error: cannot find 'Group' in scope"

**原因**: Models/Group.swift がビルドターゲットに含まれていない

**解決策**:
1. Models/Group.swift を選択
2. Inspector → Target Membership で "わりメモ" にチェック

### ビルドエラー: "Cannot find 'GroupManager' in scope"

**原因**: ViewModels/GroupManager.swift がビルドターゲットに含まれていない

**解決策**:
1. ViewModels/GroupManager.swift を選択
2. Inspector → Target Membership で "わりメモ" にチェック

### Previewが表示されない

**解決策**:
1. Xcode → Product → Clean Build Folder (Cmd+Shift+K)
2. Xcode を再起動
3. Preview を Resume（再生ボタンをクリック）

### データが保存されない

**確認事項**:
- Info.plist に Privacy 設定があるか確認
- UserDefaults の権限が正しいか確認
- シミュレータのストレージが満杯でないか確認

## ✅ 動作確認チェックリスト

- [ ] Xcodeでビルドが成功
- [ ] シミュレータで起動確認
- [ ] ホーム画面が表示される
- [ ] グループ作成ができる
- [ ] メンバー追加ができる
- [ ] 支払い登録ができる
- [ ] 精算計算が正しい
- [ ] データが保存される（アプリ再起動後も存在）
- [ ] LINE共有ボタンが機能する
- [ ] UIが正しく表示される（レイアウトズレなし）

## 📦 App Store提出準備

### 必須設定

1. **App Icons**
   - 1024x1024px の App Icon を用意
   - Assets.xcassets に配置

2. **Launch Screen**
   - Launch Screen を作成（Option）

3. **Privacy Policy**
   - App Store Connect で Privacy Policy URL を設定

4. **Screenshots**
   - 各デバイスでスクリーンショット撮影

### リリースビルド

```bash
# Archive 生成
xcodebuild -scheme わりメモ -configuration Release archive

# または Xcode内で Product → Archive
```

## 🔗 参考リンク

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Xcode Documentation](https://developer.apple.com/xcode/)
- [iOS App Development](https://developer.apple.com/ios/)

## 📝 注意事項

- UserDefaults はシミュレータとデバイスで異なる場所に保存されます
- 本番環境では iCloud Sync の実装を検討してください
- AdMob 統合時は、Info.plist に必要なキーを追加してください

---

**Last Updated**: 2026年5月20日
