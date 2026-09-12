#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-seenews-backend}"
REGION="${REGION:-asia-northeast1}"
SCHEDULER_LOCATION="${SCHEDULER_LOCATION:-asia-northeast1}"
JOB_NAME="${JOB_NAME:-newsnow-crawler}"
SCHEDULER_JOB_NAME="${SCHEDULER_JOB_NAME:-newsnow-crawler}"
SCHEDULER_SERVICE_ACCOUNT="${SCHEDULER_SERVICE_ACCOUNT:?Set SCHEDULER_SERVICE_ACCOUNT}"
IMAGE="${IMAGE:-asia-northeast1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/newsnow-backend}"

export CLOUDSDK_CORE_PROJECT="$PROJECT_ID"

# Deploy the one-shot crawler. The image must contain run_news_job.py.
gcloud run jobs deploy "$JOB_NAME" \
  --image="$IMAGE" \
  --region="$REGION" \
  --tasks=1 \
  --max-retries=1 \
  --memory=512Mi \
  --cpu=1 \
  --set-env-vars="ARTICLE_BUCKET=seenews-news-json-327343217815,ARTICLE_OBJECT=articles.json,RUN_CRAWLER_IN_SERVICE=false"

RUN_URI="https://run.googleapis.com/apis/run.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/jobs/${JOB_NAME}:run"

if gcloud scheduler jobs describe "$SCHEDULER_JOB_NAME" --location="$SCHEDULER_LOCATION" >/dev/null 2>&1; then
  gcloud scheduler jobs update http "$SCHEDULER_JOB_NAME" \
    --location="$SCHEDULER_LOCATION" \
    --schedule="*/5 * * * *" \
    --uri="$RUN_URI" \
    --http-method=POST \
    --oauth-service-account-email="$SCHEDULER_SERVICE_ACCOUNT" \
    --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"
else
  gcloud scheduler jobs create http "$SCHEDULER_JOB_NAME" \
    --location="$SCHEDULER_LOCATION" \
    --schedule="*/5 * * * *" \
    --uri="$RUN_URI" \
    --http-method=POST \
    --oauth-service-account-email="$SCHEDULER_SERVICE_ACCOUNT" \
    --oauth-token-scope="https://www.googleapis.com/auth/cloud-platform"
fi
