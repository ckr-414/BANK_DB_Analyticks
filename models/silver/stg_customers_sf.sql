{{ config(materialized='incremental', unique_key='customer_id', incremental_strategy='merge') }}

SELECT
  customer_id, customer_name, email, region, segment,
  signup_date, is_active, updated_at
FROM {{ source('bronze', 'customers_raw') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) = 1  -- dedups any duplicate customer_id rows

{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}