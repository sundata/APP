# TestFlight 配布手順

## 前提

- macOS + Xcode 16 以降
- Apple Developer Program（Team ID：`HQ9A6C8C3R`、他アプリと共通）
- App Store Connect で Bundle ID `jp.co.sundata.swimfinder` のアプリを作成済み
- `Config/SwimFinder-Info.plist` の `ITSAppUsesNonExemptEncryption` は `false`（暗号化申告不要）

## 1. ローカル確認

```bash
cd SWIM_RESULTS/SwimFinderCore && swift test
cd .. && xcodebuild -project SwimFinder.xcodeproj -scheme SwimFinder \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## 2. バージョン更新

`SwimFinder.xcodeproj` の Build Settings（両ターゲット）で

- `MARKETING_VERSION`（例：1.0.0）
- `CURRENT_PROJECT_VERSION`（ビルド番号。アップロードごとに +1）

## 3. アーカイブとアップロード（Xcode）

1. Xcode で `SwimFinder` スキーム、Destination「Any iOS Device (arm64)」を選択
2. Product → Archive
3. Organizer → Distribute App → App Store Connect → Upload
4. 自動署名（Automatic）を使用。`Config/SwimFinder.entitlements` は空

### コマンドラインの場合

```bash
xcodebuild -project SwimFinder.xcodeproj -scheme SwimFinder -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/SwimFinder.xcarchive archive

xcodebuild -exportArchive -archivePath build/SwimFinder.xcarchive \
  -exportOptionsPlist Config/ExportOptions-AppStore.plist -exportPath build/export
```

`Config/ExportOptions-AppStore.plist` は `shift-techo/Config/ExportOptions-AppStore.plist` を流用し、
`method` を `app-store-connect`、`teamID` を `HQ9A6C8C3R` にする。

## 4. App Store Connect

1. TestFlight タブでビルドの処理完了を待つ（10〜30 分）
2. 「輸出コンプライアンス」は Info.plist の設定により自動で「不要」
3. 内部テスター（社内）へ配信 → 外部テスターは Beta App Review が必要
4. テスト情報に以下を記載
   - 非公式アプリであること
   - 公式サイトは Safari 表示で開くだけで、API・スクレイピングは使っていないこと
   - ログイン不要

## 5. テスターへの確認依頼項目

- [ ] 選手名を入力 → 公式選手検索が開き、貼り付けで検索できる
- [ ] 大会名 + 年度 → 公式大会一覧が開く
- [ ] 履歴が 10 件で打ち止めになり、重複がまとまる
- [ ] お気に入りに公式 URL を保存 / 公式以外の URL は拒否される
- [ ] 設定から履歴・お気に入りを一括削除できる
- [ ] 文字サイズ最大（アクセシビリティ）でも主要導線が完了できる
- [ ] VoiceOver でボタン・入力欄・非公式表記が読み上げられる
- [ ] ダークモードで文字が読める

## 6. 提出前チェック

- App Privacy：「データは収集されません」
- スクリーンショット：6.7 インチ / 6.1 インチ（`APP_STORE.md` の説明文と整合）
- サポート URL・プライバシーポリシー URL（`PRIVACY_POLICY.md` を公開）
- 審査メモ（`APP_STORE.md` の「審査メモ」を転記）
