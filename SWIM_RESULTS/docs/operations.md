# 運用手順：公式サイト変更時の停止・復旧

## 1. 現行（Mode B）でのリスクと対応

Mode B はアプリから公式サイトのデータを取得しないため、公式サイトの仕様変更で結果が壊れて表示されることはありません。
影響を受けるのは **公式 URL の変更** のみです。

| 事象 | 検知方法 | 対応 |
| --- | --- | --- |
| `/player-search` や `/tournament/list` の URL 変更 | 週 1 回、ブラウザで `OfficialSite` の URL を手動確認（自動巡回はしない） | `SwimFinderCore/OfficialSite.swift` の URL を更新し、`OfficialSiteTests` を修正してリリース |
| 公式サイト全体のドメイン変更 | 同上 | `OfficialSite.host` を更新。旧 URL のお気に入りは `pageKind` が `nil` になり開けなくなるため、移行メッセージを追加 |
| 公式サイトが検索語の URL パラメータに対応 | 同上 | `OfficialSiteLaunch` に URL クエリ生成を追加し、クリップボード手順を省略できるようにする |
| 公式サイトの長期障害 | ユーザー報告 | アプリ側で対応できないため、ホームに「公式サイトがメンテナンス中の可能性」の注意文を出す（要リリース） |

### 停止が必要な場合

- 公式側から「アプリ経由のアクセスを止めてほしい」と要請があった場合は、App Store から配信停止し、`data-source-decision.md` に経緯を記録する。
- Mode B ではアプリが公式サイトへ直接リクエストを送らない（Safari 表示はユーザー操作による通常のブラウザアクセス）ため、サーバー側の緊急停止機構は不要。

## 2. Mode A へ移行した場合の停止・復旧（設計）

### Kill Switch

- リモート設定（当社管理の静的 JSON、例：`https://<当社ドメイン>/swimfinder/config.json`）で `resultsProviderEnabled: false` を配信すると、
  アプリは `DisabledSwimResultsProvider` に切り替わり、Mode B の導線のみになる。
- 設定取得に失敗した場合は **前回値** を使い、初回起動時は無効（Mode B）とする。

### 検知

| 事象 | 検知 |
| --- | --- |
| 必須キー欠落（仕様変更） | `SwimResultsError.specChangeSuspected` の発生率をローカル集計し、閾値超過で画面に注意表示（個人情報・検索語は含めない） |
| 429 多発 | `rateLimited` 発生時は `Retry-After` に従い、連続 3 回で当該セッション中の自動再試行を停止 |
| 5xx 継続 | 一定回数で「公式サイト側の障害」表示に切り替え |

### 手順

1. 事象確認 → Kill Switch を `false` に設定（数分でユーザーへ反映）
2. `docs/source-investigation.md` に変更内容を追記
3. `ResponseValidator` の契約と `ResponseDecoders` を更新、`FixtureSwimResultsProvider` に新レスポンス形式の fixture を追加
4. 単体・結合テスト → TestFlight → App Store 審査
5. 新バージョンの普及を確認後、Kill Switch を `true` に戻す（旧バージョンには最小対応バージョンを配信し Mode B に固定）

### 訂正・削除要請

公式側で記録の訂正・削除があった場合、キャッシュ期限（許諾で定めた `maxAge`）内に反映されない可能性がある。
要請を受けたら Kill Switch でキャッシュ無効化フラグ（`cacheEpoch`）を更新し、全端末のキャッシュを破棄する。

## 3. 定期チェックリスト

- [ ] 公式 URL（トップ / 選手検索 / 大会一覧 / 選手詳細 / 大会詳細）がブラウザで開ける
- [ ] 公式本体サイト（swim.or.jp）の利用規約・問い合わせ窓口の掲載状況（Phase 0 時点は DB エラーで未確認）
- [ ] App Store のプライバシー表示が「データは収集されません」のままであること
- [ ] `swift test`（SwimFinderCore）と `xcodebuild test` が緑
