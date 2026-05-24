# Databricks README

## 位置づけ

Databricks 配下で使う SQL の置き場と主導線をまとめる。最終形は CSV を Managed Volume 経由で実テーブル(`workspace.default.customers`)へ COPY INTO する。

## 主導線(Databricks 側)

1. `sql-test` / `sql-catalog`(疎通)
2. `volume-create`(Managed Volume `raw_csv` 作成)
3. Volume へ CSV を載せる(Phase 1: `volume-upload` で直接 / Phase 2+: GCS + Cloud Run Job 経由)
4. `table-create`(`customers` テーブル作成)
5. `table-copy`(COPY INTO、冪等)
6. `table-verify`(row_count 確認)

## コマンド

```bash
doppler run -- make sql-test
doppler run -- make volume-create
doppler run -- make volume-upload \
  LOCAL_FILE=./data/customers.csv \
  VOLUME_PATH=/Volumes/workspace/default/raw_csv/customers.csv
doppler run -- make table-create
doppler run -- make table-copy
doppler run -- make table-verify
doppler run -- make volume-clean
```

## SQL の中身

- `sql/foundation/`
  - [01_connectivity.sql](sql/foundation/01_connectivity.sql)
  - [02_catalog.sql](sql/foundation/02_catalog.sql)
  - [03_values_seed.sql](sql/foundation/03_values_seed.sql)
- `sql/volume/`
  - [01_create_managed_volume.sql](sql/volume/01_create_managed_volume.sql)
  - [02_drop_volume_artifacts.sql](sql/volume/02_drop_volume_artifacts.sql)
- `sql/table/`
  - [01_create_target_table.sql](sql/table/01_create_target_table.sql)
  - [02_copy_into_from_volume.sql](sql/table/02_copy_into_from_volume.sql)
  - [03_verify_table.sql](sql/table/03_verify_table.sql)

## 詳細

- 作業計画書: [docs/04_work_plan.md](../docs/04_work_plan.md)
- 確定スコープ: [docs/01_confirmed_scope.md](../docs/01_confirmed_scope.md)
- 検証記録: [docs/02_pipeline_validation.md](../docs/02_pipeline_validation.md)
- 技術的債務: [docs/03_technical_debt.md](../docs/03_technical_debt.md)
