# Swim Finder（競泳結果 公式サイト検索アプリ）

日本語で選手名または大会名を入力し、日本水泳連盟の公式結果サイト
「Results of Japan Swimming」（https://result.swim.or.jp/）の検索ページへ安全かつ迷わず到達するための iPhone アプリです。

> 本アプリは日本水泳連盟および公式結果サイトとは無関係の **非公式アプリ** です。
> 結果本文の取得・保存・転載は行いません。

## 採用モード：Mode B（公式サイト遷移）

Phase 0 の調査（[docs/source-investigation.md](docs/source-investigation.md)）で、公式サイトの `/api/v1/*` は非公開・非文書化、非ブラウザ UA は 403、利用規約・問い合わせ窓口を確認できなかったため、
仕様書の基準に従い **Mode B** を MVP として採用しました（[docs/data-source-decision.md](docs/data-source-decision.md)）。

| 項目 | 内容 |
| --- | --- |
| 公式 API 呼び出し | しない |
| HTML スクレイピング / DOM 注入 / 自動入力 | しない |
| 公式サイトの表示 | `SFSafariViewController` で公式ページをそのまま表示 |
| 検索語の受け渡し | 公式サイトが URL パラメータ非対応のため、アプリが検索語をクリップボードへコピーし、公式ページで貼り付けて検索 |
| 端末内に保存するもの | 検索条件（検索語・年度）と公式 URL、検索日時（最大 10 件）、お気に入りの公式 URL |
| 外部送信 | なし（分析 SDK・広告 SDK なし） |

## 構成

```
SWIM_RESULTS/
├── SwimFinder.xcodeproj          # Xcode プロジェクト（iOS 17+ / Swift 6 / SwiftUI / SwiftData）
├── SwimFinder/                   # アプリ本体（Feature 単位 + MVVM）
│   ├── App/                      # エントリポイント・依存性注入（AppEnvironment）・RootView
│   ├── Core/DesignSystem/        # 44pt タップ領域・Dynamic Type・色以外での状態表現
│   ├── Core/OfficialSite/        # SFSafariViewController ラッパーと表示状態
│   ├── Features/Home             # ホーム（選手から探す / 大会から探す / 直近検索 / 情報源）
│   ├── Features/Search           # 選手検索・大会検索（共通 SearchViewModel）
│   ├── Features/Favorites        # 公式 URL のお気に入り
│   ├── Features/Settings         # 履歴削除・情報源・免責・プライバシーポリシー・制約説明
│   ├── Services/Persistence      # SwiftData（RecentSearchRecord / FavoriteRecord / LocalStore）
│   └── Services/Clipboard.swift  # クリップボード書き込み（テスト用差し替え可）
├── SwimFinderCore/               # 純粋ロジックの Swift Package（UI 非依存・Linux でもテスト可）
├── SwimFinderUITests/            # XCUITest（-uiTesting で Safari を開かず確認画面を表示）
├── Config/                       # Info.plist / entitlements
├── docs/                         # 調査・決定・API 契約・運用手順・配布手順
├── PRIVACY_POLICY.md
└── APP_STORE.md                  # App Store 用日本語説明文
```

### SwimFinderCore の主な型

| 型 | 役割 |
| --- | --- |
| `OfficialSite` | 公式 URL の定義。公式ドメイン判定、数値 ID 検証、URL 種別判定。非公開 API の URL は持たない |
| `QueryNormalizer` | 前後空白・全角空白・連続空白の正規化、2 文字未満チェック、姓名分割 |
| `OfficialSiteLaunch` | Mode B の「コピーして公式ページを開く」プランの生成（履歴項目・案内文含む） |
| `RecentSearch` / `SearchHistoryPolicy` / `FavoriteLink` | 端末内履歴（最大 10 件・重複排除）とお気に入り（公式 URL のみ） |
| `SwimResultsProviding` | 将来の Mode A 用データ取得契約。Mode B では `DisabledSwimResultsProvider` を注入し常に `.notPermitted` |
| `SwimResultsError` | offline / dns / timeout / 429 / 5xx / 壊れたレスポンス / 仕様変更疑い を区別。0 件と失敗を混同しない |
| `RaceRound` / `FinalResultPolicy` | 決勝 → タイム決勝 → 最終順位 の優先。分類不能は決勝扱いしない |
| `ResponseValidator` | Mode A 用。必須キー欠落を「0 件」ではなく `specChangeSuspected` として扱う |
| `SearchDebouncer` | Mode A 用のデバウンス・キャンセル |
| `FixtureSwimResultsProvider` | 架空データのテスト用実装（実在の選手・記録は含まない） |

## ビルドとテスト

### 必要環境

- macOS + Xcode 16 以降（iOS 17 SDK、Swift 6）
- Core パッケージのみは Linux の Swift 6.0 ツールチェーンでもテストできます

### Core ユニットテスト（macOS / Linux）

```bash
cd SWIM_RESULTS/SwimFinderCore
swift test
```

### アプリのビルドと UI テスト（macOS）

```bash
cd SWIM_RESULTS
xcodebuild -project SwimFinder.xcodeproj -scheme SwimFinder \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

xcodebuild -project SwimFinder.xcodeproj -scheme SwimFinder \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

UI テストは `-uiTesting` 起動引数で SwiftData をインメモリにし、Safari 表示の代わりに
開こうとした公式 URL と案内文を表示する確認画面を出します（公式サイトへのアクセスは発生しません）。
`-seedHistory` を追加すると架空の履歴・お気に入りが投入されます。

## 主要導線

1. ホーム → 「選手から探す」 → 選手名入力 → 「公式サイトで検索」
   → 検索語がコピーされ、`https://result.swim.or.jp/player-search` が Safari 表示で開く
   → 公式ページの「選手名」欄に貼り付けて検索
2. ホーム → 「大会から探す」 → 大会名（任意で年度）入力 → 「公式サイトで検索」
   → `https://result.swim.or.jp/tournament/list` が開く
3. 履歴タップで同じ手順を再実行、お気に入りに公式ページ URL を保存して再表示
4. 設定 → 検索履歴・お気に入りの一括削除、情報源・免責・プライバシーポリシー・制約説明

## 既知の制約

- 公式サイトが URL パラメータでの検索条件受け渡しに対応していないため、検索語の貼り付けが 1 手順必要です
- 公式の選手検索は今年度の登録選手が対象（公式サイト側の仕様）
- 同姓同名の選手・同名の大会はアプリで自動確定せず、公式ページで所属・学種・性別・開催期間などを確認して選びます
- アプリ内に結果一覧・タイムは表示しません（Mode A 許諾後に `SwimResultsProviding` の実装を追加）
- 公式本体サイト（swim.or.jp）が調査時点で DB エラーのため、利用規約・問い合わせ窓口は未確認です

## 関連ドキュメント

- [docs/source-investigation.md](docs/source-investigation.md) — Phase 0 調査結果
- [docs/data-source-decision.md](docs/data-source-decision.md) — Mode B 採用の判断と Mode A 移行条件
- [docs/mode-a-api-contract.md](docs/mode-a-api-contract.md) — Mode A 移行時のデータモデル / API 契約
- [docs/operations.md](docs/operations.md) — 公式サイト変更時の停止・復旧手順
- [docs/testflight.md](docs/testflight.md) — TestFlight 配布手順
- [PRIVACY_POLICY.md](PRIVACY_POLICY.md) — プライバシーポリシー草案
- [APP_STORE.md](APP_STORE.md) — App Store 用日本語説明文
