# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリの目的

ローカル CSV を **GCS → Cloud Run Jobs → Databricks Managed Volume → Databricks Table** の順で取り込むパイプライン学習リポジトリ。前身 `study-databricks-import`(Files API で直接 Volume → `read_files()` + MATERIALIZED VIEW)を拡張し、前段に GCS + Cloud Run、最終段に COPY INTO での実テーブル取込を足した後継。

Databricks 側は **Free Edition のみ** を前提にする。前提にしない: Free Trial / 有償 workspace / 管理者権限 / Databricks Connect / GCS external location・external volume。catalog は常に `workspace` 固定。

**設計の肝**: Free Edition は GCS を external volume として直接マウントできないため、**Cloud Run Job (`csv-to-volume`) が「GCS DL → Files API PUT」を仲介** して Managed Volume へ載せる。詳細は [docs/04_work_plan.md](docs/04_work_plan.md)。

## 必須: doppler 経由で実行する(Databricks 系)

Databricks 系 `make` target は秘密(`DWH_DATABRICKS_TOKEN` 等)を環境変数から読む。secret は doppler で注入するため `doppler run --` を前置する。GCS / Cloud Run 系 target は `gcloud` 認証下で実行する(doppler 不要)。

```bash
doppler setup --project kuro-dev-k --config dev --no-interactive   # 初回のみ
doppler run -- make table-verify
```

## セットアップ & 主要コマンド

```bash
make install          # .venv 作成 + pip install -e .  (doppler 不要)

# Databricks SQL (doppler run -- 前置)
doppler run -- make sql-test        # SELECT 1 (疎通確認)
doppler run -- make sql-catalog     # current_catalog() → workspace
doppler run -- make volume-create   # Managed Volume workspace.default.raw_csv 作成
doppler run -- make volume-upload LOCAL_FILE=./data/customers.csv VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv
doppler run -- make table-create    # CREATE TABLE workspace.default.customers
doppler run -- make table-copy      # COPY INTO from volume (冪等)
doppler run -- make table-verify    # row_count 確認 (期待値 3)
doppler run -- make volume-clean    # table と volume を drop

# GCP pipeline (gcloud auth)
make gcs-bucket-create
make gcs-upload CSV=./data/customers.csv
doppler run -- make secret-create   # PAT を Secret Manager へ (doppler で token を注入)
make job-deploy
make job-run OBJECT=incoming/customers.csv
```

テストフレームワークや lint は未導入。検証は上記 `make` target の手動実行で行う。

## アーキテクチャ (big picture)

target は **3 本の経路** に落ちる:

1. **SQL 経路** — `Makefile` → `scripts/databricks_sql_test.sh` → `src/sql_connectivity.py`。
   `databricks-sql-connector` で SQL Warehouse に接続し SQL を実行。`DATABRICKS_TOKEN` (= `DWH_DATABRICKS_TOKEN`)。`sql-*` / `volume-create` / `volume-clean` / `table-*` がこれ。
2. **Files API 経路** — `Makefile` → `scripts/databricks_volume_upload.sh`(curl PUT)。`volume-upload` のみ。ローカルから直接 Volume へ上げる(Phase 1 検証用)。
3. **GCP 経路** — `gcloud` で GCS / Cloud Run Jobs / Artifact Registry / Secret Manager を操作。
   - `scripts/gcs_upload.sh`(`gcs-upload`)
   - `scripts/deploy_cloudrun_job.sh`(`job-deploy`: image build/push + Cloud Run Job deploy)
   - `scripts/run_cloudrun_job.sh`(`job-run`: Job 実行)
   - Cloud Run Job の本体は `src/volume_uploader.py`(`google-cloud-storage` で DL → Files API PUT)。

`sql_connectivity.py` の引数:
- `--mode query|catalog|values` … 定義済みフロー
- `--sql-file <path>` … `.sql` を `;` 分割して順次実行(volume/table 系 target はこれ経由)
- `--query "<SQL>"` … 単発 SQL

### トークンの scope に注意

`DWH_DATABRICKS_TOKEN` は **`sql, files` の両 scope** を持つ scoped PAT。Cloud Run Job 側はこの PAT を Secret Manager `databricks-pat` に格納し、env `DATABRICKS_FILES_TOKEN` として mount する。upload (`files` scope) が 403 等で失敗する場合は token の scope を疑う。

### 接続先・GCP のデフォルト値

`Makefile` 冒頭に Databricks hostname / http_path、GCP `GCP_PROJECT=mlops-dev-a` / `GCP_REGION=asia-northeast1` / `GCS_BUCKET` / `AR_REPO` / `JOB_NAME` / `SECRET_NAME` がハードコード(`?=` なので env で上書き可)。

## SQL の定義場所と重複に注意

実行される SQL は `databricks/sql/{foundation,volume,table}/*.sql`。
ただし `--mode values` の SQL は `src/sql_connectivity.py` 内 `DEFAULT_VALUES_STATEMENTS` にも **二重定義** されている(`foundation/03_values_seed.sql` と同内容)。変えるときは両方を直す。

## ディレクトリ

```text
src/sql_connectivity.py             # SQL 経路の本体 (CLI)。※ src/ 自体を package とする (二段ネスト無し)
src/volume_uploader.py              # Cloud Run Job entrypoint: GCS DL → Files API PUT
scripts/databricks_sql_test.sh      # SQL 経路の wrapper
scripts/databricks_volume_upload.sh # Files API 経路 (curl)
scripts/gcs_upload.sh               # ローカル CSV → GCS
scripts/deploy_cloudrun_job.sh      # image build/push + Cloud Run Job deploy
scripts/run_cloudrun_job.sh         # Cloud Run Job 実行
cloudrun/Dockerfile                 # csv-to-volume Job のイメージ
databricks/sql/                     # 実行対象 SQL (foundation/volume/table)
data/                               # 参照用 CSV fixture (customers.csv / orders.csv)
docs/                               # 設計 / 確定スコープ / 検証記録 / 技術的債務
```

## 言語

ドキュメント・コミットメッセージは日本語が canonical。コード内 identifier は英語。
