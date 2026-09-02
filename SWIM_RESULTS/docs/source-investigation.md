# 情報源調査：Results of Japan Swimming（result.swim.or.jp）

- 調査日：2026-09-02（UTC 14:18〜14:25）
- 調査者：Devin（PC 版 Chrome、日本国外からのアクセス）
- 目的：`DEVIN_JAPANESE_SWIM_RESULTS_APP.md` §2 に従い、選手検索・大会検索・結果詳細の現行仕様、規約、技術方式を確認し、Mode A / Mode B の判断材料を得る
- 注意：本書に認証情報・Cookie・個人の記録は記載しない。掲載している選手名・大会名は画面遷移の確認に使った公開画面上の表示例であり、アプリには同梱しない。

## 1. 確認した URL と結果

| URL | 結果 | 備考 |
| --- | --- | --- |
| `https://result.swim.or.jp/` | ブラウザ：200（トップ = 大会検索） | curl（非ブラウザ UA）では **403**。WAF/ボット対策があると推定 |
| `https://result.swim.or.jp/player-search` | ブラウザ：200 | 選手検索画面 |
| `https://result.swim.or.jp/player-search?name=山田` | 200 だが **クエリは無視される**（入力欄は空、結果 0 件） | URL パラメータによる検索条件の引き渡しは非対応 |
| `https://result.swim.or.jp/tournament/list` | 200 | 大会検索画面 |
| `https://result.swim.or.jp/tournament/{id}` | 200 | 大会詳細（例：`/tournament/4626701`） |
| `https://result.swim.or.jp/tournament/{id}/heats/genders/{g}/swimming_styles/{s}/distances/{d}/classes/{c}/race_divisions/{r}/heats/{h}` | 200 | レース結果ページ（ページタイトル "Race Detail"） |
| `https://result.swim.or.jp/athletes/{id}` | 200 | 選手情報（例：`/athletes/58732806`） |
| `https://result.swim.or.jp/robots.txt` | **404**（Next.js の 404 ページ） | robots.txt は存在しない |
| `https://www.swim.or.jp/` → `https://aquatics.or.jp/` へリダイレクト | **"Error establishing a database connection"** | 連盟本体サイトは調査時点で障害中。利用規約・サイトポリシーは未確認 |

フッターの表記：`2025 ©Japan Aquatics`、`記録に間違いがある場合、各加盟団体・大会関係者、または各所属の担当コーチへお問い合わせください`。
結果サイト内に「利用規約」「プライバシーポリシー」「API 利用」「お問い合わせ」へのリンクは**見つからなかった**（ヘッダー・フッター・各画面を確認）。

## 2. 技術方式

- サイトは **Next.js（SPA）**。`_next/static/chunks/pages/{index,player-search,tournament/list,joc/[id],school-search}` を確認。
- 検索・一覧・詳細は **JavaScript から同一オリジンの JSON API（`/api/v1/...`）を fetch** する方式。HTML フォームの GET/POST ではない。
- ブラウザの Network（`performance.getEntriesByType('resource')`）で観測したエンドポイント（記録目的。**利用許諾は確認できていないためアプリでは使用しない**）：
  - マスター：`/api/v1/masters/{member_groups,school_classes,genders,years,periods,waterways,navigations,game_statuses,distances,swimming_styles,race_divisions,display_year}`
  - 選手検索：`/api/v1/athletes?member_group_code=99&school_class_code=99&gender_code=99&entry_group_name=`（`name`/`code` も同フォームの項目）
  - 選手詳細：`/api/v1/athletes/{id}`、`/careers`、`/best_fina_points?year=&waterway_code=`、`/swimed_races?period_code=&waterway_code=`
  - 大会検索：`/api/v1/games?year=2026&page=1&sort_order=ascend&official_code=1`
  - 大会詳細：`/api/v1/games/{id}`、`/classes`、`/races`、`/heats/genders/{g}/swimming_styles/{s}/distances/{d}/classes/{c}`
  - 結果：`/api/v1/games/{id}/results/genders/{g}/swimming_styles/{s}/distances/{d}/classes/{c}/race_divisions/{r}/heats/{h}`（+ `/comparing?result_ids[]=...` でラップ比較）
- レスポンスヘッダー（`/api/v1/masters/genders`）：`x-ratelimit-limit: 3000`、`x-ratelimit-remaining: 2190`、`cache-control: private, must-revalidate`、`access-control-allow-origin: ""`、`x-cache-status: HIT`。
  - **レート制限が明示的に存在**する。CORS は同一オリジン前提。
- 非ブラウザ UA（curl）は HTML/robots.txt ともに 403 → **ボット/スクレイパー排除の意図がある**と読み取れる。
- Google Analytics（`UA-192123009-1`）を利用。

## 3. 選手から検索（`/player-search`）

画面見出し：「選手検索」。注記：「**検索対象は今年度の登録選手**」。

| 項目 | 種別 | 選択肢 / 仕様 |
| --- | --- | --- |
| 選手名 | テキスト（`name`） | 入力形式の注記なし。結果一覧は「姓 名」（全角スペース区切り）表記。空欄で検索すると全件（調査時 133,251 件）を返す |
| 所属名 | テキスト（`entry_group_name`） | |
| 競技者番号 | テキスト（`code`） | 選手詳細では下位 3 桁以外がマスクされる（`****601`） |
| 加盟団体 | セレクト | 既定「全て」。都道府県・支部（例：関東支部） |
| 学種 | セレクト | 既定「全て」。小学 / 中学 / 高校 / 大学 / 一般 等 |
| 性別 | セレクト | 既定「全て」。API マスターは 男子 / 女子 / 混合 |
| ボタン | 「検 索」「条件をクリア」 | |

- 結果一覧の列：No. / 選手名（リンク）/ 所属 / 加盟団体 / 学種 / 性別。「対象件数 N 件」表示。
- **同姓同名の識別情報 = 所属・加盟団体・学種・性別**。同一人物が複数所属（学校 + スイミングクラブ）で **別行**として出る例を確認（例：「相浦 志茉」くまぽろ / 西原中学）。
- ページング：50 件/ページ、ページ番号リンク（調査時 2,666 ページ）。並び順は五十音（読み）順と推定されるが、公式説明はない。
- 0 件時：「No Data」アイコンのみ。
- 選手名リンクは `href="#"` で JS 遷移 → `/athletes/{数値ID}`。

### 選手詳細（`/athletes/{id}`）

- 表示：選手名（漢字 + ローマ字）、競技者番号（マスク）、所属、「最終更新：YYYY/MM/DD」
- タブ：**ベストタイム**（年度・水路長で絞り込み。「出場種目別ベストタイム（pt はアクア Pt.）」）/ **種目別成績** / **出場履歴一覧**
- 生年月日・住所などの個人情報は表示されない。

## 4. 大会から検索（`/tournament/list`、トップページも同じ）

| 項目 | 種別 | 選択肢 / 仕様 |
| --- | --- | --- |
| 年度 | セレクト | 既定は当年度（調査時「2026年度」）。API は `year=2026` / `2027` を呼んでいた |
| 都道府県 | セレクト | 既定「全て」 |
| 大会名 | テキスト | 部分一致と推定（未検証） |
| ステータス | セレクト | 既定「指定なし」。一覧には「記録確定」バッジ |
| ヘッダーの「大会名で検索」 | テキスト | 全画面共通のクイック検索 |

- 結果一覧の列：開催期間（並び替え可）/ 主催団体 / 大会名（「短水路」「長水路」バッジ付き）/ 会場 / 参加人数 / ステータス。50 件/ページ、調査時 1,132 件・23 ページ。
- **同名大会の識別 = 開催期間・主催団体・会場**。

### 大会詳細（`/tournament/{id}`）

- ヘッダー：ステータス（記録確定）、開催期間（日数）、水路（短水路/長水路）、大会名、都道府県、開催施設、出場選手数（男女別）
- タブ：**種目一覧** / **レース一覧** / **大会傾向**
- 大会内の「競技者検索」（選手名・所属名）
- 種目一覧：男子/女子 × 泳法（自由形・背泳ぎ・平泳ぎ・バタフライ・個人メドレー・フリーリレー・メドレーリレー）× 距離（50m〜1500m、4x50m〜4x200m）。実施なしの距離はグレーアウト。

### レース結果（`/tournament/{id}/heats/genders/.../heats/{h}`）

- 見出し：「男子 100m 自由形」、クラス（例：「17歳以上」）セレクト
- ラウンドタブ：**「決勝(A-決勝)」「予選ランキング」「予選 N 組目」…** ← ラウンド名は公式表記として取得可能。「タイム決勝」表記が別大会に存在するかは今回のサンプルでは未確認
- サブタブ：結果一覧 / ラップ比較
- 結果表の列：順位 / 組 / レーン / 氏名（→ `/athletes/{id}`）/ 所属 / 学年 / タイム / 1位との差 / RT / アクアPt. / 備考 / ラップ
- 共有ボタン：LINE / Twitter / Facebook / リンクコピー（**公式側が結果ページの URL 共有を想定している**）

## 5. 画面遷移図（確認済み）

```
トップ(/)=大会検索 ──┬─ 大会一覧 ─ 大会詳細(/tournament/{id}) ─ 種目 ─ レース結果(/tournament/{id}/heats/...) ─ 選手(/athletes/{id})
                    └─ ヘッダー「選手検索」(/player-search) ─ 候補一覧 ─ 選手詳細(/athletes/{id}) ─ ベストタイム / 種目別成績 / 出場履歴
フッター：大会検索 / 登録団体検索 / JO標準記録突破者一覧
```

## 6. 規約上の判断材料

| 観点 | 結果 |
| --- | --- |
| 利用規約・API 利用条件 | 結果サイト内に**なし**。連盟本体サイトは障害中で確認不可 |
| robots.txt | 存在しない（404） |
| 非ブラウザアクセス | 403（WAF 相当） |
| API | 非公開・非文書化。レート制限ヘッダーあり。CORS は自サイト限定 |
| 著作権表記 | `©Japan Aquatics` |
| 問い合わせ窓口 | 結果サイト内になし（記録誤りは各加盟団体・コーチへ、との注記のみ） |
| URL パラメータでの検索条件引き渡し | **非対応**（`?name=` 無視） |
| 安定した公開 URL | `/player-search`、`/tournament/list`、`/tournament/{id}`、`/athletes/{id}`、レース結果 URL（共有ボタンあり） |

## 7. 未解決事項

1. 日本水泳連盟（Japan Aquatics）の利用規約・サイトポリシーの内容（本体サイト障害のため未確認）。復旧後に再確認し、必要なら文書で問い合わせる。
2. `/api/v1/*` のアプリ利用可否・再配布可否（公式の許可が必要。**許可があるとは推定しない**）。
3. 「タイム決勝」表記の実例と、決勝/予選以外のラウンド名一覧（`/api/v1/masters/race_divisions` に相当する公式マスターの内容）。
4. 選手名検索の一致方式（部分一致/前方一致、姓名間の空白の扱い、かな検索の可否）。フォーム挙動の観察のみで、公式仕様は不明。
5. 過年度の選手（「検索対象は今年度の登録選手」）を検索する手段の有無。
6. 失格（DSQ）・棄権（DNS）等の備考表記の実例。
7. 大会名検索の部分一致・略称対応の実挙動。

これらは Phase 2（承認後）で公式の許可・仕様を得たうえで確認する。
