# 生きてる？ バックエンド — デプロイ手順

## アーキテクチャ

```
iOS App
  │  POST /users/{device_id}/checkin     ← 签到
  │  PUT  /users/{device_id}/settings    ← 同步联系人/设置
  │  GET  /users/{device_id}/status      ← 查询状态
  ▼
Cloud Run (FastAPI)
  │  ← Firestore 読み書き
  ▲
Cloud Scheduler (5分ごと)
  └→ POST /internal/check-overdue → 期限切れ検出 → Gmail SMTP → 緊急連絡先
```

---

## Step 1 — Gmail アプリパスワードを取得

1. Google アカウント → セキュリティ → **2段階認証を有効化**
2. セキュリティ → **アプリパスワード** → 「生きてる」など任意の名前 → 生成
3. 表示された **16文字のパスワード**をメモ（スペースなし）

---

## Step 2 — Google Cloud プロジェクト作成

```bash
# Google Cloud SDK をインストール済みであること
# https://cloud.google.com/sdk/docs/install

# ログイン
gcloud auth login

# プロジェクト作成
gcloud projects create ikiteru-app-2026 --name="IkiteruApp"

# 課金アカウントを紐付け（Cloud Console から手動設定が確実）
# https://console.cloud.google.com/billing
```

---

## Step 3 — deploy.sh を編集してデプロイ

```bash
cd ikiteru-backend

# deploy.sh の先頭を編集
PROJECT_ID="ikiteru-app-2026"       # 作成したプロジェクトID
GMAIL_USER="yourname@gmail.com"      # Gmailアドレス
GMAIL_APP_PASSWORD="xxxxxxxxxxxx"    # Step1で取得した16文字

# デプロイ実行
bash deploy.sh
```

完了すると以下が表示される：
```
API URL    : https://ikiteru-backend-xxxx-an.a.run.app
Scheduler  : 5分ごとに期限切れチェック
```

---

## Step 4 — iOS App に URL を設定

`IkiteruApp/BackendConfig.swift` を編集：

```swift
enum BackendConfig {
    static let baseURL = "https://ikiteru-backend-xxxx-an.a.run.app"  // ← ここに貼り付け
}
```

Xcode でビルドし直せば完了。

---

## 動作確認

```bash
BASE="https://ikiteru-backend-xxxx-an.a.run.app"

# ヘルスチェック
curl $BASE/

# 手動チェックイン
curl -X POST "$BASE/users/test-device-001/checkin"

# ステータス確認
curl "$BASE/users/test-device-001/status"

# 超時チェックを手動実行（SECRET は deploy.sh の出力から）
curl -X POST "$BASE/internal/check-overdue" \
  -H "X-Scheduler-Secret: YOUR_SECRET"
```

---

## コスト見積もり（個人利用）

| サービス | 無料枠 | 月額目安 |
|---------|--------|---------|
| Cloud Run | 200万リクエスト/月 | **無料** |
| Firestore | 50,000読み/日, 20,000書き/日 | **無料** |
| Cloud Scheduler | 3ジョブ/月まで | **無料** |
| Gmail SMTP | 500通/日 | **無料** |
| **合計** | | **¥0〜数十円** |

---

## セキュリティメモ

- `/internal/check-overdue` は `X-Scheduler-Secret` ヘッダーで保護
- Gmail アプリパスワードは Cloud Run の環境変数に保存（コードに書かない）
- Firestore のデータはデバイスIDで分離（他ユーザーのデータにアクセス不可）
