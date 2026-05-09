# バックエンド環境設定ガイド

## OpenAI API 設定

### 1. 環境変数に API キーを設定

`.env` ファイルをプロジェクトルート（`API/`フォルダ直下）に作成：

```bash
# API/.env
OPENAI_API_KEY=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
```

### 2. Cloud Run にデプロイするとき

GCP Cloud Run のシークレット管理を使用：

```bash
# シークレットを作成
gcloud secrets create openai-api-key --data-file=- <<< "sk-proj-..."

# Cloud Run サービスをデプロイ時にシークレットをマウント
gcloud run deploy newsnow-backend \
  --set-secrets=OPENAI_API_KEY=openai-api-key:latest \
  ...
```

### 3. ローカル開発で実行

```bash
cd API/

# 依存関係をインストール（OpenAI パッケージ追加済み）
pip install -r requirements.txt

# サーバー起動（.env ファイルが自動ロードされる）
uvicorn server:app --reload --port 8000
```

---

## AI 分析 API エンドポイント

### `/v1/ai/analyze` - 基本分析 （POST）

**リクエスト例：**
```bash
curl -X POST "https://api.example.com/v1/ai/analyze?article_id=123" \
  -H "X-User-ID: user_12345" \
  -H "Authorization: Bearer token"
```

**クエリパラメータ：**
- `article_id`: (オプション) DB内の記事ID
- `title`: (article_id 未指定時は必須) 記事タイトル
- `summary`: (article_id 未指定時は必須) 記事概要
- `content`: (オプション) 記事本文

**レスポンス例：**
```json
{
  "articleId": "123",
  "summary": "新型製品の発表が市場に影響を与える可能性がある",
  "threePoints": [
    "新しい機能が競合製品と比較して革新的",
    "価格戦略は業界平均より10%安い",
    "発売予定は来年Q１予定"
  ],
  "importance": "テック業界の競争構図を大きく変える可能性",
  "cached": false
}
```

---

### `/v1/ai/deep-analyze` - 深度分析 （POST）

**リクエスト例：**
```bash
curl -X POST "https://api.example.com/v1/ai/deep-analyze?article_id=123" \
  -H "X-User-ID: user_12345" \
  -H "Authorization: Bearer token"
```

**クエリパラメータ：**
- `article_id`: (オプション) DB内の記事ID
- `title`: (article_id 未指定時は必須) 記事タイトル
- `summary`: (article_id 未指定時は必須) 記事概要
- `basic_analysis`: (オプション) 基本分析の結果を参考にする

**レスポンス例：**
```json
{
  "articleId": "123",
  "impactAnalysis": "株価に直接的な上昇圧力、競合企業の戦略見直しを迫る",
  "futureOutlook": "3ヶ月内に類似製品発表、6ヶ月で市場シェア変動開始",
  "actionAdvice": "投資家は関連銘柄の動向監視を推奨。消費者は価格比較検討を"
}
```

---

## コスト推定

**OpenAI API（gpt-4o-mini）の料金：**
- 入力: ¥0.075 / 1Mトークン
- 出力: ¥0.30 / 1Mトークン

**ユース別コスト：**
- 基本分析1件: 約¥0.02-0.03
- 深度分析1件: 約¥0.05-0.08
- Pro ユーザー（月50記事分析）: 約¥200-300/月

**最適化：**
- 分析結果はDB キャッシュされる（2回目以降は API 呼び出しなし）
- 期間内の重複分析は自動的に無料化

---

## トラブルシューティング

### "OpenAI API key not configured" エラー

```bash
# 1. .env ファイルが存在するか確認
ls -la API/.env

# 2. 環境変数が読み込まれているか確認
python -c "import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv('OPENAI_API_KEY')[:20] + '...')"

# 3. Cloud Run の場合は secrets 設定を確認
gcloud secrets list | grep openai
```

### API 時間超過エラー

- タイムアウトが 30秒に設定されています
- 長い記事は summary フィールドは自動的に最初の 500 文字に切り詰められます
- 必要に応じて `max_tokens` を削減してください

---

## セキュリティ上の注意

⚠️ **API キーは絶対にコード内に埋め込まないでください**
- `.env` ファイルは `.gitignore` に追加
- Cloud Run ではシークレット管理機能を使用
- CloudAudit Logs で API 使用状況を監視

