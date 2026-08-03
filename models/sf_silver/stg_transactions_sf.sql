{{ config(materialized='incremental', unique_key='transaction_id', incremental_strategy='merge') }}

SELECT
  transaction_id, customer_id, transaction_date, amount,
  currency, payment_method, region, status, updated_at,{{bank_analytics.audit_columns()}}
FROM {{ source('raw_bronze', 'transactions_raw') }}
WHERE amount IS NOT NULL AND amount > 0   -- filters null/negative amount data quality issues
QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY updated_at DESC) = 1  -- dedups exact-duplicate transaction_ids

{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}