# わりメモ iOS アプリ開発ガイド

## プロジェクト概要

**わりメモ**は、シンプルで使いやすい割り勘・旅行精算アプリです。飲み会、旅行、同棲など、複数人での支払いを簡単に管理・精算できます。

## 開発環境構成

### 必要環境
- Xcode 15.0以上
- iOS 16.0以上
- Swift 5.9以上
- macOS 13.0以上

### 使用フレームワーク
- **SwiftUI** - UI構築
- **UserDefaults** - データ永続化
- **Foundation** - 基本機能

## プロジェクト構造

```
わりメモ/
├── WarimemoApp.swift           # アプリエントリーポイント
├── Models/
│   └── Group.swift              # データモデル（グループ、メンバー、支払い、精算）
├── Views/
│   ├── ContentView.swift         # ホーム画面
│   ├── GroupDetailView.swift     # グループ詳細画面
│   ├── SettlementResultView.swift # 精算結果画面
│   ├── NewGroupSheet.swift       # グループ作成シート
│   ├── AddPaymentSheet.swift     # 支払い追加シート
│   └── AddMemberSheet.swift      # メンバー追加シート
├── ViewModels/
│   └── GroupManager.swift        # グループ管理ViewModel
└── Utils/
    └── Extensions.swift          # 拡張機能（Color、NumberFormatter等）
```

## 主要機能

### 1. グループ管理
- グループの作成・編集・削除
- グループカラーカスタマイズ
- メモ機能

### 2. メンバー管理
- メンバーの追加・削除
- ログイン不要（名前だけで登録）

### 3. 支払い管理
- 支払い情報の記録（支払者、金額、内容、日付）
- 自動割り勘計算
- 支払い履歴表示

### 4. 精算計算
- 誰が誰にいくら払うかを自動計算
- 効率的な精算フロー表示

### 5. 共有機能
- LINE共有
- iMessage共有
- AirDrop共有
- テキストコピー

## データモデル

### Group
```swift
struct Group {
    var id: UUID
    var name: String          // グループ名
    var color: String         // HEXカラーコード
    var members: [Member]     // メンバーリスト
    var payments: [Payment]   // 支払い履歴
    var memo: String          // メモ
    var createdAt: Date       // 作成日
}
```

### Member
```swift
struct Member {
    var id: UUID
    var name: String          // メンバー名
}
```

### Payment
```swift
struct Payment {
    var id: UUID
    var payerId: UUID         // 支払者ID
    var amount: Double        // 金額
    var description: String   // 説明
    var date: Date            // 日付
    var splitAmong: [Member]  // 割り勘対象
}
```

### Settlement
```swift
struct Settlement {
    var id: UUID
    var from: String          // 支払人
    var to: String            // 受取人
    var amount: Double        // 精算金額
}
```

## デザインシステム

### カラーパレット
- **プライマリ**: `#4FC3F7` (水色)
- **セカンダリ**: `#81D4FA` (淡ブルー)
- **背景**: `#FFFFFF` (白)
- **アクセント緑**: `#43A047` (緑)
- **アクセント橙**: `#FFB300` (オレンジ)

### タイポグラフィ
- フォント: **Noto Sans JP**
- ボディ: 14pt Regular
- 見出し: 16-32pt Semibold/Bold

## データ永続化

現在はUserDefaultsを使用しています。将来的にSwiftDataへの移行を検討してください。

### 保存形式
- JSON形式でエンコード/デコード
- UserDefaults の `"warimeao_groups"` キーに保存

```swift
// 保存
if let encoded = try? JSONEncoder().encode(groups) {
    UserDefaults.standard.set(encoded, forKey: "warimeao_groups")
}

// 読み込み
if let data = UserDefaults.standard.data(forKey: "warimeao_groups"),
   let decoded = try? JSONDecoder().decode([Group].self, from: data) {
    groups = decoded
}
```

## 画面フロー

1. **Splash画面** → アプリ起動時に表示
2. **Home画面** → グループ一覧表示、新規作成ボタン
3. **グループ詳細画面** → メンバー、支払い履歴、精算結果
4. **メンバー追加** → モーダルシートで名前入力
5. **支払い追加** → モーダルシートで支払い情報入力
6. **精算結果画面** → 自動計算された精算情報を表示、共有機能

## 今後の拡張予定

### Phase 2
- [ ] Google AdMob統合（広告配置）
- [ ] Cloud同期機能
- [ ] グループURLによる他ユーザーとの共有
- [ ] 複数通貨対応

### Phase 3
- [ ] SwiftDataへのマイグレーション
- [ ] オフライン優先設計の改善
- [ ] 画像添付機能
- [ ] CSV/PDF出力

### Phase 4
- [ ] ウィジェット対応
- [ ] Apple Watch対応
- [ ] 音声入力機能

## トラブルシューティング

### データが保存されない場合
- UserDefaultsの権限を確認
- Info.plistの設定を確認
- デバイスのストレージ容量を確認

### UIが表示されない場合
- Xcodeキャッシュをクリア（Cmd+Shift+K）
- Previewをリセット
- デバイスを再起動

### 精算計算が正しくない場合
- メンバーが正しく追加されているか確認
- 支払い情報の金額や日付を確認
- GroupManager.swiftの計算ロジックをデバッグ

## ビルド・実行方法

```bash
# Xcodeで開く
open わりメモ.xcodeproj

# コマンドラインビルド（シミュレータ）
xcodebuild -scheme わりメモ -configuration Debug -sdk iphonesimulator

# アーカイブ（App Store用）
xcodebuild -scheme わりメモ -configuration Release -archivePath わりメモ.xcarchive archive
```

## ライセンス

プライベートプロジェクト

## 開発者

わりメモ開発チーム
