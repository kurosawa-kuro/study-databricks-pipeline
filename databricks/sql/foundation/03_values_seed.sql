CREATE SCHEMA IF NOT EXISTS workspace.default;

CREATE OR REPLACE TABLE workspace.default.customers (
  customer_id INT,
  name STRING,
  age INT,
  prefecture STRING,
  signup_date DATE
);

INSERT OVERWRITE workspace.default.customers
VALUES
  (1, 'Taro Yamada', 34, 'Tokyo', DATE '2024-01-10'),
  (2, 'Hanako Sato', 28, 'Osaka', DATE '2024-02-15'),
  (3, 'Ken Suzuki', 41, 'Hokkaido', DATE '2024-03-20');

CREATE OR REPLACE TABLE workspace.default.orders (
  order_id INT,
  customer_id INT,
  amount INT,
  ordered_at TIMESTAMP
);

INSERT OVERWRITE workspace.default.orders
VALUES
  (101, 1, 12000, TIMESTAMP '2024-04-01 10:30:00'),
  (102, 1, 8000, TIMESTAMP '2024-04-03 14:20:00'),
  (103, 2, 15000, TIMESTAMP '2024-04-05 09:10:00'),
  (104, 3, 6000, TIMESTAMP '2024-04-07 18:45:00');

SELECT
  c.customer_id,
  c.name,
  c.prefecture,
  COUNT(o.order_id) AS order_count,
  COALESCE(SUM(o.amount), 0) AS total_amount
FROM workspace.default.customers c
LEFT JOIN workspace.default.orders o
  ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name, c.prefecture
ORDER BY total_amount DESC;
