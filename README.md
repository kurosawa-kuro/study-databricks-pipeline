# study-databricks-pipeline

ローカル CSV を **GCS → Cloud Run Jobs → Databricks Managed Volume → Databricks Table** という GCP 経由のパイプラインで取り込む学習リポジトリ。前身 [`study-databricks-import`](../study-databricks-import/)(ローカルから Files API で直接 Volume に上げ、`read_files()` + MATERIALIZED VIEW)を拡張し、GCS / Cloud Run 連携と実テーブル取込(COPY INTO)を足したもの。

Databricks 側は **Free Edition** を前提にする(catalog は `workspace` 固定、external location / external volume は使えない)。GCS を直接マウントできないため、**Cloud Run Job が「GCS からダウンロード → Files API で Managed Volume へ upload」を仲介** する。

## 想定フロー

```text
ローカル CSV (data/*.csv)
  ── make gcs-upload ──▶ GCS  gs://<bucket>/incoming/*.csv
  ── Cloud Run Job (csv-to-volume) ──▶ Managed Volume /Volumes/workspace/default/raw_csv/
  ── COPY INTO (SQL Warehouse) ──▶ Databricks Table workspace.default.customers
```

## クイックスタート

```bash
make install                                   # .venv 作成 + pip install -e .

# ── Phase 1: GCS/Cloud Run 抜きで Databricks 側を先に通す ──
doppler run -- make volume-create              # Managed Volume raw_csv 作成
doppler run -- make volume-upload \
  LOCAL_FILE=./data/customers.csv \
  VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv
doppler run -- make table-create               # CREATE TABLE customers
doppler run -- make table-copy                 # COPY INTO (冪等)
doppler run -- make table-verify               # row_count = 3

# ── Phase 2+: GCS + Cloud Run でフルパイプライン ──
gcloud config set project mlops-dev-a
make gcs-bucket-create                          # バケット作成 (初回)
make gcs-upload CSV=./data/customers.csv        # ローカル → GCS
doppler run -- make secret-create               # PAT を Secret Manager へ
make job-deploy                                 # image build/push + Cloud Run Job deploy
make job-run OBJECT=incoming/customers.csv      # Job 実行: GCS → Volume
doppler run -- make table-copy                  # COPY INTO
doppler run -- make table-verify                # row_count 確認
```

詳細な設計・実現可能性・段階移行計画は [docs/04_work_plan.md](docs/04_work_plan.md) を参照。

## 必須: doppler 経由で実行する

Databricks 系 target は秘密(`DWH_DATABRICKS_TOKEN` 等)を環境変数から読むため、`doppler run --` を前置する。GCS / Cloud Run 系は `gcloud` 認証下で実行する。

```bash
doppler setup --project kuro-dev-k --config dev --no-interactive   # 初回のみ
```

## ドキュメント

- [docs/04_work_plan.md](docs/04_work_plan.md) — 作業計画書(設計・実現可能性・段階移行)
- [docs/01_confirmed_scope.md](docs/01_confirmed_scope.md) — 確定スコープ
- [docs/02_pipeline_validation.md](docs/02_pipeline_validation.md) — 検証記録
- [docs/03_technical_debt.md](docs/03_technical_debt.md) — 技術的債務
