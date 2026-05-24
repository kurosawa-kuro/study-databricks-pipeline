#!/usr/bin/env bash
set -euo pipefail

# Cloud Run Job を実行し、GCS のオブジェクトを Managed Volume へ転送する。
# 実行ごとに対象オブジェクト/アップロード先を env override で渡す。
# 必須 env: GCP_PROJECT GCP_REGION JOB_NAME GCS_BUCKET
# Usage: scripts/run_cloudrun_job.sh <gcs-object> [volume-path]
#   例: scripts/run_cloudrun_job.sh incoming/customers.csv

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <gcs-object> [volume-path]" >&2
  echo "Example: $0 incoming/customers.csv" >&2
  exit 2
fi

: "${GCP_PROJECT:?Missing GCP_PROJECT}"
: "${GCP_REGION:?Missing GCP_REGION}"
: "${JOB_NAME:?Missing JOB_NAME}"
: "${GCS_BUCKET:?Missing GCS_BUCKET}"

OBJECT="$1"
VOLUME_PATH="${2:-/Volumes/workspace/default/raw_csv/$(basename "${OBJECT}")}"

gcloud run jobs execute "${JOB_NAME}" \
  --region="${GCP_REGION}" \
  --project="${GCP_PROJECT}" \
  --wait \
  --update-env-vars="GCS_BUCKET=${GCS_BUCKET},GCS_OBJECT=${OBJECT},VOLUME_PATH=${VOLUME_PATH}"

echo "Executed Cloud Run Job: ${JOB_NAME} (gs://${GCS_BUCKET}/${OBJECT} -> ${VOLUME_PATH})"
