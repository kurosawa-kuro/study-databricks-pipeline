# 確定スコープ

## 対象

- Databricks Free Edition のみ
- Serverless SQL Warehouse
- Managed Volume
- Files API
- COPY INTO による実テーブル取込
- GCS(取得元)
- Cloud Run Jobs(GCS → Volume 転送エージェント)
- Artifact Registry / Secret Manager(Cloud Run 運用)

## 非対象

- Databricks Free Trial
- 有償 workspace
- Databricks Connect 主導の開発
- GCS external location / external volume(Free Edition で作れない → Cloud Run で仲介)
- 管理者権限前提の構成

## 設計上のルート

```text
ローカル CSV → GCS → Cloud Run Job (GCS DL → Files API PUT) → Managed Volume → COPY INTO → Table
```

1. `SQL Warehouse` 接続
2. `Managed Volume` (`workspace.default.raw_csv`) 作成
3. CSV を Volume へ(Phase 1: `volume-upload` で直接 / Phase 2+: GCS + Cloud Run Job)
4. `CREATE TABLE workspace.default.customers`
5. `COPY INTO ... FROM '/Volumes/.../customers.csv' FILEFORMAT = CSV`(冪等)
6. SQL で row_count 確認

## 検証ステータス

> 本リポジトリでの Databricks / GCP 実行検証は **未実施**。実装は完了しているが、実際の workspace / mlops-dev-a に対する疎通は人間検証時に行う。結果は [02_pipeline_validation.md](02_pipeline_validation.md) に記録する。

前身 `study-databricks-import` では Free Edition で `Managed Volume + Files API + read_files() + MATERIALIZED VIEW`、`current_catalog() = workspace`、`row_count = 3` まで確認済み(JSON 版)。本リポジトリは入力を CSV、最終段を COPY INTO の実テーブルに変更したため、CSV/COPY INTO 経路と GCS/Cloud Run 経路は改めて検証が必要。
