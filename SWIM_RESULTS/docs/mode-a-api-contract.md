# Mode A 移行時のデータモデル / API 契約

本文書は、公式（日本水泳連盟 / 公式結果サイト運営者）から **文書による利用許諾** を得た後に
アプリ内で結果データを表示する Mode A へ移行する際の契約案です。
許諾がない状態で本契約を実装してはいけません。現行アプリでは `DisabledSwimResultsProvider` が注入され、
すべてのメソッドが `SwimResultsError.notPermitted` を返します。

## 1. 許諾で確認すべき項目

| 項目 | 契約に反映する先 |
| --- | --- |
| 利用可能なエンドポイントと認証方式（API キー等） | `OfficialAPIClient` の設定 |
| アプリ内で表示できる項目（氏名・所属・学年・記録・順位・備考など） | `PlayerSummary` / `SwimResult` のフィールド |
| キャッシュ可能期間 | `Fetched.isStale(now:maxAge:)` の `maxAge` |
| 最大リクエスト頻度 | `RateLimiter`（未実装）と `SearchDebouncer.delay` |
| クレジット表記の文言・位置 | 結果画面フッター |
| 訂正・削除が公式側で発生した場合の反映期限 | キャッシュ無効化ポリシー |
| 個人情報（競技者番号のマスク等）の取り扱い | 表示前のマスク処理 |

## 2. Core の契約（現状の型）

```swift
protocol SwimResultsProviding: Sendable {
    func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary]
    func playerResults(playerID: String) async throws -> [SwimResult]
    func searchMeets(query: MeetQuery) async throws -> [MeetSummary]
    func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult]
}
```

- 0 件は **成功（空配列）**、失敗は **必ず throw**（`SwimResultsError`）。
- 公式レスポンスの値は文字列のまま保持し、アプリ側で推測・補完しない（`SwimResult.time` は原文、`seconds` は補助値）。
- ID は公式が発行する安定 ID を使用し、氏名から生成しない。

### エラー分類

| 状況 | `SwimResultsError` | 再試行 | 表示 |
| --- | --- | --- | --- |
| オフライン | `.offline` | 可 | 接続確認を促す |
| DNS 失敗 | `.dnsFailure` | 可 | 時間をおいて再試行 |
| タイムアウト | `.timeout` | 可 | 同上 |
| HTTP 429 | `.rateLimited(retryAfterSeconds:)` | Retry-After 後 | 待ち時間を表示 |
| HTTP 5xx | `.serverError(status:)` | 可 | 公式側の一時障害 |
| JSON 不正 | `.malformedResponse` | 不可 | 公式ページで確認を促す |
| 必須キー欠落 | `.specChangeSuspected(detail:)` | 不可 | 同上 + 運用アラート |
| 許諾なし | `.notPermitted` | 不可 | 機能停止中 |

`ResponseValidator.validateList` で必須キーを検証し、仕様変更を「0 件」と誤表示しない。

### 最終結果の判定

`RaceRound(officialLabel:)` → `FinalResultPolicy.select(from:)`

1. `決勝*`（`.final`）
2. `タイム決勝`（`.timedFinal`）
3. `最終順位` / `総合結果`（`.officialFinalStanding`）
4. 上記なし → `.unverified`（「最終結果は未確認です。公式ページで確認してください。」）

## 3. 観測済みの公式エンドポイント（参考・利用許諾前は呼び出し禁止）

Phase 0 でブラウザから観測した同一オリジン JSON API。仕様は非公開で、予告なく変わり得る。

| 用途 | パス（観測値） |
| --- | --- |
| 選手検索 | `GET /api/v1/athletes?…` |
| 選手詳細 / 経歴 / ベスト / 出場レース | `GET /api/v1/athletes/{id}`, `/careers`, `/best_fina_points`, `/swimed_races` |
| 大会一覧 / 詳細 / クラス / レース / 結果 | `GET /api/v1/games`, `/games/{id}`, `/classes`, `/races`, `/results/...` |
| マスタ | `GET /api/v1/masters/{genders,years,periods,waterways,game_statuses,distances,swimming_styles,race_divisions,member_groups,school_classes}` |

観測されたヘッダー：`x-ratelimit-limit: 3000`、`cache-control: private, must-revalidate`。
非ブラウザ UA は 403。これらを **回避してはいけない**。

## 4. Mode A 実装時の追加コンポーネント（案）

```
SwimFinderCore/
  OfficialAPIClient        # URLSession + 許諾済み認証、User-Agent にアプリ名とバージョン
  RateLimiter              # 許諾された頻度を超えないトークンバケット
  ResponseDecoders         # ResponseValidator → PlayerSummary / MeetSummary / SwimResult
  ResultCache              # Fetched<Value> + maxAge、取得日時を UI に必ず表示
SwimFinder/
  Features/Results         # 結果一覧（決勝優先・取得日時・クレジット・公式ページで確認ボタン）
```

### 表示要件（仕様書より）

- 取得日時を表示する
- 「公式ページで最新情報を確認」ボタンを常設する
- 「最終結果」と表示するのは `FinalResultPolicy` が `.confirmed` を返した場合のみ
- 取得失敗を「該当なし」と表示しない

## 5. 移行手順

1. 許諾文書を `docs/permission/` に保存し、`data-source-decision.md` を更新
2. `OfficialAPIClient` を実装し、`AppEnvironment.resultsProvider` を差し替える（`DisabledSwimResultsProvider` は Feature Flag のフォールバックとして残す）
3. `FixtureSwimResultsProvider` で既存テスト（同姓同名・0 件・429・5xx・仕様変更）を Mode A 画面に対して再実行
4. 公式ステージング（提供される場合）で結合テスト
5. `docs/operations.md` の停止手順（Kill Switch）を有効化してリリース
