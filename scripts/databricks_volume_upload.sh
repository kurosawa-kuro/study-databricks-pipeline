#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <local-file> <volume-path>" >&2
  echo "Example: $0 ./data/events.json /Volumes/workspace/default/raw_logs/sample.json" >&2
  exit 2
fi

LOCAL_FILE="$1"
VOLUME_PATH="$2"

: "${DATABRICKS_SERVER_HOSTNAME:?Missing DATABRICKS_SERVER_HOSTNAME}"
: "${DATABRICKS_FILES_TOKEN:?Missing DATABRICKS_FILES_TOKEN}"

if [[ ! -f "${LOCAL_FILE}" ]]; then
  echo "Local file not found: ${LOCAL_FILE}" >&2
  exit 2
fi

curl --fail-with-body --request PUT \
  "https://${DATABRICKS_SERVER_HOSTNAME}/api/2.0/fs/files${VOLUME_PATH}?overwrite=true" \
  --header "Authorization: Bearer ${DATABRICKS_FILES_TOKEN}" \
  --header "Content-Type: application/octet-stream" \
  --data-binary @"${LOCAL_FILE}"

echo
echo "Upload succeeded: ${LOCAL_FILE} -> ${VOLUME_PATH}"
