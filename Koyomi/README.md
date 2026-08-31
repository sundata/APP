# Koyomi（こよみ）

日本のシフト勤務者向けのミニマルな勤務カレンダー。早番・日勤・遅番・夜勤・休みを数タップで登録し、月間の勤務時間と概算給与を確認して、金額を含まない月間シフト画像を家族やパートナーに共有できる iOS アプリ（MVP）。

## 環境要件

| 項目 | バージョン |
| --- | --- |
| Xcode | 16.0 以降（`objectVersion = 77` / file system synchronized groups を使用） |
| iOS | 17.0 以降 |
| Swift | 6.0 |
| 依存 | ローカル SwiftPM パッケージ `KoyomiCore` + Google Mobile Ads / UMP のみ |

構成:

```text
Koyomi/
  Koyomi.xcodeproj              アプリ本体 + UI テストターゲット
  Config/Koyomi-Info.plist      Info.plist（位置情報の権限文言なし）
  Koyomi/App/                   エントリポイント、DI（AppEnvironment）、RootView（3 タブ）
  Koyomi/Core/DesignSystem/     色・タイポ・共通コンポーネント
  Koyomi/Core/Persistence/      SwiftData モデルと KoyomiStore
  Koyomi/Features/              Onboarding / Calendar / ShiftEditor / ShiftTemplates /
                                PayrollSummary / Sharing / Settings
  Koyomi/Services/              通知・バックアップ・エンタイトルメント・時計の protocol と実装
  Koyomi/Resources/             Localizable.xcstrings（日本語 String Catalog）
  KoyomiUITests/                主要フローの UI テストとスクリーンショット取得
  KoyomiCore/                   プラットフォーム非依存のロジック（SwiftPM、Linux でもテスト可）
```

## 機能（MVP）

- **カレンダー**：日曜始まりの月表示、日本の祝日、スワイプと前月/次月ボタン、今日に戻る、1 日 1 シフト。
- **単日登録**：日付タップでボトムシート。テンプレート選択・メモ（100 文字）・保存・削除・Undo。
- **一括登録**：連続した日付範囲に 1 つのテンプレートを適用（最大 62 日、上書き件数を確認してから実行、Undo 可）。
- **集計**：勤務/休み/未設定の日数、計上時間・深夜時間・残業時間、基本給・深夜手当・残業手当・交通費・概算合計。時給未設定時は `時給を設定すると表示されます`。
- **共有**：1080 × 1350 の縦型 PNG。年月・グリッド・シフト略称・凡例・`Koyomi` の小さなブランド表記のみで、時給・概算給与・メモ・氏名・端末識別子・広告は含まない。プレビュー後に標準共有シートへ。
- **通知**：毎月の入力リマインダーと翌日のシフト通知。スイッチを ON にしたときだけ権限を要求し、拒否時は設定アプリへの案内を出す。
- **データ**：JSON バックアップの書き出し/読み込み（schema version 検証、追加 or 置き換え、置き換えは二重確認）、すべてのデータ削除（二重確認 → 初回起動状態へ）。

将来の Pro 版に備えて `EntitlementProviding` を用意しているが、購入 UI は実装していない。

## 給与計算のルール

1. シフト時間 = 終了 − 開始（跨日は +24 時間）
2. 計上時間 = max(0, シフト時間 − 休憩)
3. 深夜時間 = シフトと深夜時間帯（既定 22:00–05:00）の実際の交差
4. 残業時間 = 1 日の計上時間が所定労働（既定 8 時間）を超えた分
5. 基本給は全計上時間、深夜手当と残業手当はそれぞれ加算（重複時は両方加算）
6. 交通費は勤務日数分を加算
7. 計算は整数の「分」で行い、円は最後に四捨五入

集計画面には `表示金額は概算です。実際の給与・税金・社会保険料とは異なる場合があります。` を常に表示する。

## AdMob の設定

Google Mobile Ads SDK と User Messaging Platform（UMP）は Swift Package Manager で導入している。AdMob App ID とバナー広告ユニット ID は Koyomi の正式な値を設定している。

- 初回ガイド、共有プレビュー、共有画像、削除確認では広告を出さない。バナーはタブバーやシートを遮らない位置に置く。
- UI テスト（`-uiTesting`）とスクリーンショット取得（`-screenshotTesting`）では広告を完全に無効化する。
- 同意が必要な地域では UMP の同意取得後にのみ広告を要求する。

## 実行

```bash
open Koyomi/Koyomi.xcodeproj
# スキーム: Koyomi / 実行先: iPhone SE (3rd gen) 以降のシミュレータまたは実機
```

## テスト

給与・シフト時間・深夜交差・残業・祝日・バックアップのロジックは `KoyomiCore` にあり、macOS でも Linux でも実行できる。

```bash
cd Koyomi/KoyomiCore && swift test
```

UI テスト（要 Xcode / macOS）:

```bash
cd Koyomi
xcodebuild test -project Koyomi.xcodeproj -scheme Koyomi \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

UI テストは起動引数 `-uiTesting` で、広告なし・ネットワークなし・固定時計（2026-03-01 JST）・インメモリ DB の構成に切り替わるため、結果が日によって変わらない。

## アーキテクチャ

- **KoyomiCore（純ロジック）**: `KoyomiCalendar`（Gregorian + `Asia/Tokyo`、`dayKey` 生成の単一入口）、`CalendarMonth`（日曜始まりのグリッド）、`JapaneseHolidayCalendar`（固定祝日・ハッピーマンデー・春分/秋分・振替休日・国民の休日・2019/2020/2021 の特例）、`ShiftDefinition`/`ShiftTemplate`/`ShiftAssignment`、`PayrollSettings`/`PayrollCalculator`、`BackupDocument`/`BackupCodec`、`ShiftShareContent`。SwiftUI・SwiftData・UIKit・UserNotifications に依存しない。
- **永続化**: `UserSettingsRecord` / `ShiftTemplateRecord` / `ShiftEntryRecord`（`dayKey` は一意）。書き込みはすべて `KoyomiStore`（`@MainActor`）経由で、View は `ModelContext` を直接触らない。
- **テンプレートのスナップショット**: `ShiftEntryRecord` は名称・時間・休憩・色をコピーして保持するため、後からテンプレートを変更しても過去の勤務時間と給与は変わらない。
- **整数分での計算**: 給与は分と円の整数で計算し、浮動小数の時間を事実の源にしない。
- **依存性注入**: `AppEnvironment` が `KoyomiStore`・`NotificationScheduling`・`BackupProviding`・`EntitlementProviding`・`ClockProviding` を束ねる。UI テストでは固定時計とスタブ通知に差し替える。
- **旧データの移行**: 旧バージョン（占い）のストアは移行対象がないため、開けない場合は起動を止めずに新しいストアを作り直す。

## プライバシー

アカウント登録なし、位置情報なし、連絡先なし、クラウド送信なし。通知は端末内のローカル通知のみ、共有は標準共有シートのみ。詳細は `PRIVACY_POLICY.md` とアプリ内の `KoyomiLegalText`（同じ内容で管理）を参照。

## 既知の制限・未完了項目

- **Apple 環境での検証が未実施**: 本リファクタは Linux 環境で実装したため、`KoyomiCore` の単体テストのみ実行済み。Xcode でのビルド、UI テスト、シミュレータ（iPhone SE / Pro / Pro Max、ライト/ダーク、Dynamic Type、VoiceOver）での目視確認は未実行。
- **App Store 用スクリーンショット**: `Submission/Screenshots` には旧デザインの画像が残っている。`-screenshotTesting` の UI テストで撮り直す必要がある。
- **App アイコン**: 未更新。
- **交通費**: 「勤務日ごとの固定額」のみ対応（距離・経路・定期券は非対応）。
- **税・社会保険**: 計算しない（概算給与のみ）。

## 次のステップ

1. macOS + Xcode 16 でビルドし、UI テストを iPhone SE と大画面 iPhone で実行する。
2. `-screenshotTesting` でスクリーンショットを撮り直し、`Submission/Screenshots` を差し替える。
3. App Store のプライバシーラベル（アカウントなし・位置情報なし・広告 SDK のみ）を実装と突き合わせる。
4. アクセシビリティ（Dynamic Type 最大 / VoiceOver）の目視確認と調整。
