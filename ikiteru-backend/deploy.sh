#!/usr/bin/env bash
# =============================================================
# 生きてる？ Backend — Google Cloud デプロイスクリプト
# 使い方: bash deploy.sh
# =============================================================
set -euo pipefail

# ── 設定 ────────────────────────────────────────────────────
# 秘密情報はスクリプトに書かず、環境変数で渡してください:
#   GMAIL_USER=... GMAIL_APP_PASSWORD=... SCHEDULER_SECRET=... bash deploy.sh
PROJECT_ID="${PROJECT_ID:-ikiteru-2026}"
REGION="${REGION:-asia-northeast1}"          # 東京
SERVICE_NAME="${SERVICE_NAME:-ikiteru-backend}"
GMAIL_USER="${GMAIL_USER:-}"
GMAIL_APP_PASSWORD="${GMAIL_APP_PASSWORD:-}"
SCHEDULER_SECRET="${SCHEDULER_SECRET:-}"
# ──────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 0. 入力チェック ────────────────────────────────────────
if [[ -z "$PROJECT_ID" || -z "$GMAIL_USER" || -z "$GMAIL_APP_PASSWORD" || -z "$SCHEDULER_SECRET" ]]; then
    error "環境変数 PROJECT_ID / GMAIL_USER / GMAIL_APP_PASSWORD / SCHEDULER_SECRET を設定してください（例: SCHEDULER_SECRET=\$(openssl rand -hex 32)）"
fi

info "プロジェクト: $PROJECT_ID  リージョン: $REGION"

# ── 1. gcloud 設定 ─────────────────────────────────────────
info "gcloud プロジェクトを設定..."
gcloud config set project "$PROJECT_ID"

# ── 2. 必要な API を有効化 ─────────────────────────────────
info "GCP APIを有効化..."
gcloud services enable \
    run.googleapis.com \
    firestore.googleapis.com \
    cloudscheduler.googleapis.com \
    cloudbuild.googleapis.com \
    --project "$PROJECT_ID"

# ── 3. Firestore データベース作成 ──────────────────────────
info "Firestoreデータベースを作成..."
gcloud firestore databases create \
    --location="$REGION" \
    --project "$PROJECT_ID" 2>/dev/null || warn "Firestoreは既に存在します（スキップ）"

# ── 4. Cloud Run にデプロイ ────────────────────────────────
info "Cloud Runにデプロイ中..."
gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --region "$REGION" \
    --platform managed \
    --allow-unauthenticated \
    --set-env-vars "GMAIL_USER=${GMAIL_USER},GMAIL_APP_PASSWORD=${GMAIL_APP_PASSWORD},SCHEDULER_SECRET=${SCHEDULER_SECRET}" \
    --memory 512Mi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 5 \
    --project "$PROJECT_ID"

# ── 5. Cloud Run の URL を取得 ─────────────────────────────
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region "$REGION" \
    --format "value(status.url)" \
    --project "$PROJECT_ID")
info "Cloud Run URL: $SERVICE_URL"

# ── 6. Cloud Scheduler 設定（5分ごと）─────────────────────
info "Cloud Schedulerを設定..."
gcloud scheduler jobs create http ikiteru-overdue-check \
    --location "$REGION" \
    --schedule "*/5 * * * *" \
    --uri "${SERVICE_URL}/internal/check-overdue" \
    --http-method POST \
    --headers "X-Scheduler-Secret=${SCHEDULER_SECRET}" \
    --time-zone "Asia/Tokyo" \
    --project "$PROJECT_ID" 2>/dev/null || \
gcloud scheduler jobs update http ikiteru-overdue-check \
    --location "$REGION" \
    --schedule "*/5 * * * *" \
    --uri "${SERVICE_URL}/internal/check-overdue" \
    --http-method POST \
    --headers "X-Scheduler-Secret=${SCHEDULER_SECRET}" \
    --time-zone "Asia/Tokyo" \
    --project "$PROJECT_ID"

# ── 7. 完了 ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} デプロイ完了！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  API URL    : $SERVICE_URL"
echo "  Scheduler  : 5分ごとに期限切れチェック"
echo ""
echo -e "${YELLOW}iOS App の BackendConfig.swift に以下を設定してください:${NC}"
echo "  BASE_URL = \"$SERVICE_URL\""
echo ""
echo "ヘルスチェック:"
echo "  curl $SERVICE_URL/"
