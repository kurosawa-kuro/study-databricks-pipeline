# Pipeline 検証記録

## 検証対象

`ローカル CSV → GCS → Cloud Run Job → Managed Volume → COPY INTO → Table` が Databricks Free Edition + GCP (mlops-dev-a) で成立するかを確認する。

> ステータス: **未実施**(実装完了。実 workspace / GCP への疎通は人間検証時に実行し、結果を本ファイルへ追記する)。

## 検証手順(予定)

### Phase 1: Databricks 側(GCS/Cloud Run 抜き)

```bash
doppler run -- make volume-create
doppler run -- make volume-upload \
  LOCAL_FILE=./data/customers.csv \
  VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv
doppler run -- make table-create
doppler run -- make table-copy
doppler run -- make table-verify     # 期待値: row_count = 3
doppler run -- make table-copy       # 再実行
doppler run -- make table-verify     # 期待値: row_count = 3 のまま(COPY INTO の冪等性)
```

期待結果(記入待ち):

- [ ] `CREATE VOLUME IF NOT EXISTS workspace.default.raw_csv`
- [ ] `Upload succeeded: ./data/customers.csv -> /Volumes/workspace/default/raw_csv/customers.csv`
- [ ] `CREATE TABLE IF NOT EXISTS workspace.default.customers`
- [ ] COPY INTO 後 `row_count = 3`
- [ ] COPY INTO 再実行で row_count が増えない

### Phase 2+: GCS + Cloud Run

```bash
gcloud config set project mlops-dev-a
make gcs-bucket-create
make gcs-upload CSV=./data/customers.csv
doppler run -- make secret-create
make job-deploy
make job-run OBJECT=incoming/customers.csv
doppler run -- make table-copy
doppler run -- make table-verify
```

期待結果(記入待ち):

- [ ] `gs://mlops-dev-a-databricks-pipeline/incoming/customers.csv` に配置
- [ ] Cloud Run Job `csv-to-volume` 成功
- [ ] Volume に `customers.csv` が存在(`LIST '/Volumes/workspace/default/raw_csv/'`)
- [ ] `table-verify` で row_count = 3

## 関連 SQL

- [volume/01_create_managed_volume.sql](../databricks/sql/volume/01_create_managed_volume.sql)
- [volume/02_drop_volume_artifacts.sql](../databricks/sql/volume/02_drop_volume_artifacts.sql)
- [table/01_create_target_table.sql](../databricks/sql/table/01_create_target_table.sql)
- [table/02_copy_into_from_volume.sql](../databricks/sql/table/02_copy_into_from_volume.sql)
- [table/03_verify_table.sql](../databricks/sql/table/03_verify_table.sql)
