{{
  config(
    materialized='incremental',
    unique_key=['transaction_date','region'],
    incremental_strategy='merge'
  )
}}

SELECT
  transaction_date,
  region,
  COUNT(*) AS num_transactions,
  SUM(CASE WHEN status='COMPLETED' THEN amount ELSE 0 END) AS completed_sales,
  SUM(CASE WHEN status='REFUNDED' THEN amount ELSE 0 END)  AS refunded_amount,
  COUNT(DISTINCT customer_id) AS unique_customers
FROM {{ ref('stg_transactions') }}
{% if is_incremental() %}
WHERE transaction_date >= (SELECT DATEADD(day,-3,MAX(transaction_date)) FROM {{ this }})  -- reprocess a trailing window for late data
{% endif %}
GROUP BY 1,2