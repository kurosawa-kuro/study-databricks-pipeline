"""GCS -> Databricks Managed Volume の転送エージェント。

Cloud Run Job の entrypoint。Free Edition は GCS を external volume として
直接マウントできないため、本ジョブが「GCS からダウンロード -> Databricks Files API
(PUT /api/2.0/fs/files) で Managed Volume へ upload」を仲介する。

環境変数:
  GCS_BUCKET                  取得元バケット名 (例: mlops-dev-a-databricks-pipeline)
  GCS_OBJECT                  取得元オブジェクト (例: incoming/customers.csv)
  VOLUME_PATH                 アップロード先 (例: /Volumes/workspace/default/raw_csv/customers.csv)
  DATABRICKS_SERVER_HOSTNAME  例: dbc-xxxx.cloud.databricks.com
  DATABRICKS_FILES_TOKEN      files scope を持つ PAT (Cloud Run では Secret Manager 経由)
"""

from __future__ import annotations

import os
import sys

import requests
from google.cloud import storage


def require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        print(f"Missing required environment variable: {name}", file=sys.stderr)
        raise SystemExit(2)
    return value


def download_from_gcs(bucket: str, obj: str) -> bytes:
    client = storage.Client()
    blob = client.bucket(bucket).blob(obj)
    if not blob.exists():
        print(f"GCS object not found: gs://{bucket}/{obj}", file=sys.stderr)
        raise SystemExit(2)
    data = blob.download_as_bytes()
    print(f"Downloaded gs://{bucket}/{obj} ({len(data)} bytes)")
    return data


def upload_to_volume(
    hostname: str, token: str, volume_path: str, data: bytes
) -> None:
    url = f"https://{hostname}/api/2.0/fs/files{volume_path}"
    response = requests.put(
        url,
        params={"overwrite": "true"},
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/octet-stream",
        },
        data=data,
        timeout=300,
    )
    if not response.ok:
        print(
            f"Files API upload failed: {response.status_code} {response.text}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    print(f"Upload succeeded: gs://... -> {volume_path}")


def main() -> None:
    bucket = require_env("GCS_BUCKET")
    obj = require_env("GCS_OBJECT")
    volume_path = require_env("VOLUME_PATH")
    hostname = require_env("DATABRICKS_SERVER_HOSTNAME")
    token = require_env("DATABRICKS_FILES_TOKEN")

    data = download_from_gcs(bucket, obj)
    upload_to_volume(hostname, token, volume_path, data)
    print("csv-to-volume job finished.")


if __name__ == "__main__":
    main()
