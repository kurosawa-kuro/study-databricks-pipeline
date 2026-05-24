# Cloud Run Job "csv-to-volume" のイメージ。
# GCS から CSV を取得し Databricks Files API で Managed Volume へ upload する。
FROM python:3.12-slim

WORKDIR /app

# 依存のみ先に入れてレイヤキャッシュを効かせる
RUN pip install --no-cache-dir \
    "google-cloud-storage>=2.16" \
    "requests>=2.31"

COPY src/__init__.py src/__init__.py
COPY src/volume_uploader.py src/volume_uploader.py

# Cloud Run Job は実行時に env (GCS_BUCKET / GCS_OBJECT / VOLUME_PATH /
# DATABRICKS_SERVER_HOSTNAME / DATABRICKS_FILES_TOKEN) を受け取る。
ENTRYPOINT ["python", "-m", "src.volume_uploader"]
