{{ config(materialized='incremental', unique_key='customer_id', incremental_strategy='merge') }}

SELECT
  c.customer_id, c.customer_name, c.segment, c.region,
  COUNT(t.transaction_id) AS lifetime_transactions,
  SUM(CASE WHEN t.status='COMPLETED' THEN t.amount ELSE 0 END) AS lifetime_value
FROM {{ ref('stg_customers_sf') }} c
LEFT JOIN {{ ref('stg_transactions_sf') }} t ON c.customer_id = t.customer_id
GROUP BY 1,2,3,4