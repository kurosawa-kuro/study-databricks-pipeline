-- Managed Volume 上の CSV を customers テーブルへ取り込む。
-- COPY INTO は取り込み済みファイルを記録するため、再実行しても重複行を作らない(冪等)。
-- 既存スキーマに合わせて明示 CAST する(CSV は型情報を持たないため)。
COPY INTO workspace.default.customers
FROM (
  SELECT
    CAST(customer_id AS INT)    AS customer_id,
    CAST(name AS STRING)        AS name,
    CAST(age AS INT)            AS age,
    CAST(prefecture AS STRING)  AS prefecture,
    CAST(signup_date AS DATE)   AS signup_date
  FROM '/Volumes/workspace/default/raw_csv/customers.csv'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true');
