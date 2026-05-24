# Pipeline 検証記録

## 検証対象

`ローカル CSV → GCS → Cloud Run Job → Managed Volume → COPY INTO → Table` が Databricks Free Edition + GCP (mlops-dev-a) で成立するか。

> ステータス: **GCP 経路は検証済み (2026-05-24)**。Phase 1 / Phase 2+ ともに end-to-end 成功。

## Phase 2+: GCS + Cloud Run(検証済み 2026-05-24)

実行コマンド:

```bash
make gcs-bucket-create
make gcs-upload CSV=./data/customers.csv
doppler run -- make secret-create
make job-deploy
doppler run -- make volume-create
make job-run OBJECT=incoming/customers.csv
```

確認結果:

- [x] `gs://mlops-dev-a-databricks-pipeline/incoming/customers.csv` に配置
- [x] PAT を Secret Manager `databricks-pat` (version 1) に登録
- [x] イメージを Artifact Registry `databricks-pipeline/csv-to-volume:latest` に build/push
- [x] Cloud Run Job `csv-to-volume` デプロイ成功
- [x] Job 実行成功(execution `csv-to-volume-q5wkj` completed)
- [x] Volume 着地確認: `LIST '/Volumes/workspace/default/raw_csv/'` →
      `customers.csv` (size=148)

### 必要だった IAM(deploy スクリプトに冪等で組込済)

Cloud Run の実行 SA(`<projectNumber>-compute@developer.gserviceaccount.com`)に以下が必要:

- `roles/secretmanager.secretAccessor`(secret `databricks-pat`)
- `roles/storage.objectViewer`(bucket)

初回 deploy 時に未付与だと `Permission denied on secret ...` で失敗する。`scripts/deploy_cloudrun_job.sh` が deploy 前に冪等付与するよう修正済み。

## Phase 1: Databricks 側 COPY INTO(検証済み 2026-05-24)

> Volume 上の CSV(Cloud Run Job が配置)を実テーブルへ COPY INTO。クリーン状態(table drop 後)で計測。

```bash
doppler run -- make sql-query QUERY="DROP TABLE IF EXISTS workspace.default.customers"
doppler run -- make table-create
doppler run -- make table-copy     # 1st
doppler run -- make table-verify
doppler run -- make table-copy     # 2nd
doppler run -- make table-verify
```

確認結果:

- [x] `CREATE TABLE IF NOT EXISTS workspace.default.customers`
- [x] 1st COPY INTO: `num_inserted_rows = 3`
- [x] verify: `row_count = 3`
- [x] 2nd COPY INTO: `num_inserted_rows = 0`(取込済みファイルを skip)
- [x] verify: `row_count = 3` のまま(**COPY INTO の冪等性を確認**)

### 注意した点

- `workspace.default.customers` は前身 `study-databricks-import` の `sql-values`(VALUES seed と同じ 3 行)で既に存在しており、最初の素朴な COPY INTO では `row_count = 6` になった。COPY INTO 自体は正しく 3 行追加していた。クリーン計測のため table を drop してから測り直した。

## 関連 SQL

- [volume/01_create_managed_volume.sql](../databricks/sql/volume/01_create_managed_volume.sql)
- [volume/02_drop_volume_artifacts.sql](../databricks/sql/volume/02_drop_volume_artifacts.sql)
- [table/01_create_target_table.sql](../databricks/sql/table/01_create_target_table.sql)
- [table/02_copy_into_from_volume.sql](../databricks/sql/table/02_copy_into_from_volume.sql)
- [table/03_verify_table.sql](../databricks/sql/table/03_verify_table.sql)
