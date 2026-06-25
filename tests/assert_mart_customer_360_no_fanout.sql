-- tests/assert_mart_customer_360_no_fanout.sql
-- Mart must not have more rows than distinct active customers
WITH mart AS (SELECT COUNT(*) AS r FROM {{ ref('mart_customer_360') }}),
     src  AS (SELECT COUNT(DISTINCT customer_id) AS r
              FROM {{ ref('stg_customers') }} WHERE is_active=TRUE)
SELECT * FROM mart, src WHERE mart.r > src.r;
