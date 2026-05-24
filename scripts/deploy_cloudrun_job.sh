#!/usr/bin/env bash
set -euo pipefail

# Artifact Registry にイメージを build/push し、Cloud Run Job をデプロイ(作成/更新)する。
# 必須 env: GCP_PROJECT GCP_REGION AR_REPO JOB_NAME IMAGE SECRET_NAME DATABRICKS_SERVER_HOSTNAME
# 任意 env: RUNTIME_SA (Job 実行 SA)

: "${GCP_PROJECT:?Missing GCP_PROJECT}"
: "${GCP_REGION:?Missing GCP_REGION}"
: "${AR_REPO:?Missing AR_REPO}"
: "${JOB_NAME:?Missing JOB_NAME}"
: "${IMAGE:?Missing IMAGE}"
: "${SECRET_NAME:?Missing SECRET_NAME}"
: "${DATABRICKS_SERVER_HOSTNAME:?Missing DATABRICKS_SERVER_HOSTNAME}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Artifact Registry repo (冪等)
if ! gcloud artifacts repositories describe "${AR_REPO}" \
      --location="${GCP_REGION}" --project="${GCP_PROJECT}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format=docker --location="${GCP_REGION}" --project="${GCP_PROJECT}"
fi

# 2. build & push (build context は repo root, Dockerfile は cloudrun/)
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet
docker buildx build --platform linux/amd64 \
  -f "${ROOT_DIR}/cloudrun/Dockerfile" \
  -t "${IMAGE}" --push "${ROOT_DIR}"

# 3. 実行 SA に必要ロールを付与 (冪等)。
#    RUNTIME_SA 未指定なら Cloud Run のデフォルト = <projectNumber>-compute@developer.gserviceaccount.com
EFFECTIVE_SA="${RUNTIME_SA}"
if [[ -z "${EFFECTIVE_SA}" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "${GCP_PROJECT}" --format='value(projectNumber)')"
  EFFECTIVE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
fi
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
  --member="serviceAccount:${EFFECTIVE_SA}" \
  --role="roles/secretmanager.secretAccessor" \
  --project="${GCP_PROJECT}" >/dev/null
if [[ -n "${GCS_BUCKET:-}" ]]; then
  gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
    --member="serviceAccount:${EFFECTIVE_SA}" \
    --role="roles/storage.objectViewer" >/dev/null
fi

# 4. Cloud Run Job deploy (create or update)
gcloud run jobs deploy "${JOB_NAME}" \
  --image="${IMAGE}" \
  --region="${GCP_REGION}" \
  --project="${GCP_PROJECT}" \
  --set-env-vars="DATABRICKS_SERVER_HOSTNAME=${DATABRICKS_SERVER_HOSTNAME}" \
  --set-secrets="DATABRICKS_FILES_TOKEN=${SECRET_NAME}:latest" \
  ${RUNTIME_SA:+--service-account="${RUNTIME_SA}"}

echo "Deployed Cloud Run Job: ${JOB_NAME} (${IMAGE})"
