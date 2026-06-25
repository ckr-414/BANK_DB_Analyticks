-- tests/assert_no_future_transactions.sql
SELECT transaction_id, transaction_date
FROM {{ ref('stg_transactions') }}
WHERE transaction_date > CURRENT_DATE();
