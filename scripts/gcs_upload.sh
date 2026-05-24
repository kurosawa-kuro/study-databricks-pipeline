#!/usr/bin/env bash
set -euo pipefail

# ローカル CSV を GCS の incoming/ プレフィックスへ配置する。
# Usage: GCS_BUCKET=... scripts/gcs_upload.sh <local-csv> [gcs-object]

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <local-csv> [gcs-object]" >&2
  exit 2
fi

CSV="$1"
: "${GCS_BUCKET:?Missing GCS_BUCKET}"
OBJECT="${2:-incoming/$(basename "${CSV}")}"

if [[ ! -f "${CSV}" ]]; then
  echo "Local file not found: ${CSV}" >&2
  exit 2
fi

gcloud storage cp "${CSV}" "gs://${GCS_BUCKET}/${OBJECT}"
echo "Uploaded: ${CSV} -> gs://${GCS_BUCKET}/${OBJECT}"
