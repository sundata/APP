# Koyomi（こよみ）

空と星から届く、わたしだけの毎日占い。星座・当日の天気・日付・季節から、日本語の「今日のおまもり占い」を生成する iOS アプリ（MVP）。

## 環境要件

| 項目 | バージョン |
| --- | --- |
| Xcode | 16.0 以降（`objectVersion = 77` / file system synchronized groups を使用） |
| iOS | 17.0 以降 |
| Swift | 6.0 |
| 依存 | ローカル SwiftPM パッケージ `KoyomiCore` のみ（外部ライブラリなし） |

構成:

```text
Koyomi/
  Koyomi.xcodeproj        アプリ本体 + UI テストターゲット
  Config/Koyomi.entitlements  WeatherKit の entitlement
  Koyomi/App/             エントリポイント、DI コンテナ、RootView
  Koyomi/Core/DesignSystem/   色・タイポ・共通コンポーネント
  Koyomi/Core/Persistence/    SwiftData モデルとストア
  Koyomi/Features/        Onboarding / Today / Calendar / Profile / ShareCard
  Koyomi/Services/        天気・位置情報・通知・時計の protocol と実装
  Koyomi/Resources/       Localizable.xcstrings（日本語 String Catalog）
  KoyomiUITests/          onboarding → 今日ページの UI テスト
  KoyomiCore/             プラットフォーム非依存のロジック（SwiftPM、Linux でもテスト可）
```

## WeatherKit の設定

WeatherKit はクライアントに API キーを埋め込まず、Apple Developer アカウントの capability で認証する。

1. Apple Developer で App ID `jp.co.sundata.koyomi`（任意の Bundle ID に変更可）を作成し、**WeatherKit** を有効化する。
2. [developer.apple.com](https://developer.apple.com/account/resources/services/list) の Services で対象アプリの WeatherKit を有効化する。
3. Xcode で `Koyomi` ターゲット → Signing & Capabilities に開発チームを設定する（`Config/Koyomi.entitlements` に `com.apple.developer.weatherkit` が入っている）。
4. Bundle ID を変更した場合は `PRODUCT_BUNDLE_IDENTIFIER` も合わせて変更する。

WeatherKit の設定前でもアプリは動作する。天気の取得に失敗した場合は、天気を偽装せず「お天気情報を取得できませんでした」と明示し、季節と日付から占いを生成する。

位置情報は `When In Use` のみを要求し、バックグラウンド測位は使わない。緯度経度は天気取得のためだけに使用し、永続化・ログ出力はしない（保存するのは都市名と天気の要約のみ）。

## AdMob の設定

Google Mobile Ads SDK と User Messaging Platform（UMP）は Swift Package Manager で導入している。AdMob App ID とバナー広告ユニット ID は Koyomi の正式な値を設定している。

公開前に以下を変更する:

1. AdMob の「プライバシーとメッセージ」で対象地域向けメッセージを作成する。アプリは起動ごとに UMP の同意状態を更新し、同意後のみ広告を要求する。
2. 公開構成の Info.plist に、利用する広告配信元の最新 `SKAdNetworkItems` を Google の公式手順に従って追加する。

シミュレータは自動的にテスト端末として扱われる。実機開発では正式広告をクリックせず、必要に応じて Google のテスト端末設定またはテスト広告ユニット ID を使う。

## 実行

```bash
open Koyomi/Koyomi.xcodeproj
# スキーム: Koyomi / 実行先: iPhone 15 以降のシミュレータまたは実機
```

## テスト

ロジック（星座・日付境界・決定性・内容安全）は `KoyomiCore` にあり、macOS でも Linux でも実行できる。

```bash
cd Koyomi/KoyomiCore && swift test          # 41 tests
```

UI テスト（要 Xcode / macOS）:

```bash
cd Koyomi
xcodebuild test -project Koyomi.xcodeproj -scheme Koyomi \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

UI テストは起動引数 `-uiTesting` で、mock 天気・固定時計・権限ダイアログなし・インメモリ DB の構成に切り替わるため、結果が日によって変わらない。

## アーキテクチャ

- **KoyomiCore（純ロジック）**: `Zodiac`、`KoyomiCalendar`/`Season`、`WeatherCategory`/`City`/`WeatherSnapshot`、`DailyFortune`、`StableSeed`、`ContentLibrary`、`TemplateFortuneGenerator`、`ContentSafety`、`ShareCardContent`。UI・ネットワーク・端末 API に依存しない。
- **決定的な生成**: `localDate + zodiac + weatherCategory + contentVersion` から FNV-1a でシードを作る（Swift の `Hasher` はプロセスごとに変わるため使わない）。同じ入力なら常に同じ結果になる。日番号による回転で、7 日間は headline・総評・アクションが重複しない。
- **天気の抽象化**: WeatherKit の詳細な condition は 9 種類の `WeatherCategory` に写像する。占いは天気そのものではなくカテゴリに依存するため、気温の小さな変動で結果が変わらない。
- **依存性注入**: `WeatherProviding`、`FortuneGenerating`、`LocationProviding`、`NotificationScheduling`、`ClockProviding` を `AppEnvironment` が束ねる。View は WeatherKit・Core Location・SwiftData を直接触らない。
- **永続化**: `FortuneRecord` に当日の `DailyFortune` を JSON で保存し、履歴は後から書き換えない（生成ロジックを更新しても過去の記録は変化しない）。天気は要約のみを保存し、座標は保存しない。
- **状態と例外**: 天気取得は 4 秒でタイムアウト（無限ローディングにしない）→ 当日キャッシュがあれば取得時刻付きで表示 → なければ天気なしの fallback。位置情報が拒否された場合は再要求せず都市選択に切り替える。前面復帰時に権限とローカル日付を再評価する。
- **荒天時**: 雷雨・猛暑・厳寒などは占いで危険をぼかさず、客観的な注意文を先に表示する。

## 前提と割り切り（Assumptions and Trade-offs）

- **天文情報**: 月相は WeatherKit の日次予報から取得できたときのみ使う。取得できない場合は推測せず、文面から月相の言及を外す（偽の天文情報を作らない）。
- **コンテンツ**: 占い文は「規則エンジン + 審査済みテンプレート」で生成し、オンライン LLM を初期表示の依存先にしない。文面は `ContentLibrary` にあり、`ContentSafety` のテストで禁止表現（断定・医療・妊娠・事故・投資など）を検査している。
- **String Catalog**: 画面の UI 文言は `Localizable.xcstrings`（ja）に登録した。占いコンテンツ本体は日本語前提の文体設計のため `KoyomiCore` の Swift コードに置いている（他言語対応時はロケール別のコンテンツプールを追加する想定）。
- **通知**: ユーザーがリマインダーをオンにするまで `UNUserNotificationCenter` の権限要求を行わない。通知文は不安をあおらない文面のみ。
- **共有**: シェアカードは `ImageRenderer` でオフライン生成し、日付・星座・短い総評・ラッキーカラー・ブランド名のみを含む（ニックネーム・位置・生年月日は含めない）。
- **アカウント**: 登録不要。生年月日・履歴・お気に入りは端末内のみ。「わたし」タブから全削除できる。

## 既知の制限・未完了項目

- **Apple 環境での検証が未実施**: 本 MVP は Linux 環境で実装したため、`KoyomiCore` の 41 テストのみ実行済み。Xcode でのビルド、UI テスト、シミュレータでのスクリーンショット取得（浅色/深色）は未実行。macOS + Xcode 16 での初回ビルド時に、WeatherKit API 名や SwiftData のスキーマ調整が必要になる可能性がある。
- **スクリーンショット未添付**: 上記のため、ライト/ダークの画面キャプチャは未取得。
- **アプリ層のテスト**: `TodayViewModel` のキャッシュ・fallback 判定は現状 UI テストと手動確認に依存する（ロジックの決定性・境界値は KoyomiCore 側でカバー）。ViewModel 単体テスト用の XCTest ターゲットは未追加。
- **App アイコン / アセットカタログ**: 未作成（システム既定のまま）。
- **プライバシーポリシー**: `KoyomiLegalText.privacyPolicy` は草案。公開前に法務確認と問い合わせ先の記載が必要。
- **カレンダー**: 月表示は自作の簡易グリッド。祝日表示や月をまたぐスワイプは未対応。
- **iPhone SE / 最大 Dynamic Type**: レイアウトは可変対応で組んでいるが、実機・シミュレータでの目視確認は未実施。

## 次のステップ

1. macOS + Xcode 16 でビルドし、WeatherKit の API 差分を解消。UI テストとアクセシビリティ検査（Dynamic Type 最大 / VoiceOver）を実行する。
2. ライト/ダークのスクリーンショットを取得し、README に添付する。
3. `TodayViewModel` の単体テスト（キャッシュ表示・タイムアウト・日付跨ぎ）を追加する。
4. App アイコンとアセットカタログ、ローンチ体験の作り込み。
5. コンテンツプールをネイティブライターがレビューし、`contentVersion` を上げて拡充する。
6. App Store のプライバシーラベルを実装と突き合わせ、審査用の説明文を用意する。
