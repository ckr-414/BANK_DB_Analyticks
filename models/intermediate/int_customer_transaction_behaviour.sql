-- models/intermediate/int_customer_transaction_behaviour.sql
{{ config(materialized='table',
    schema=var('intermediate_schema'), database=var('target_database'), tags=['intermediate']) }}
SELECT
    a.customer_id, t.category,
    COUNT(t.transaction_id)                              AS txn_count,
    SUM(t.gross_amount)                                  AS total_spent,
    AVG(t.gross_amount)                                  AS avg_spend,
    MAX(t.gross_amount)                                  AS max_single_spend,
    MIN(t.transaction_date)                              AS first_txn_date,
    MAX(t.transaction_date)                              AS last_txn_date,
    COUNT(DISTINCT t.transaction_month)                  AS active_months,
    {{ audit_columns(enter_from='MIN(t.enter_dt)', enter_by_from='MIN(t.enter_by)') }}
FROM {{ ref('stg_transactions') }} t
JOIN {{ ref('stg_accounts') }} a ON t.account_id=a.account_id
WHERE t.direction='DEBIT'
GROUP BY 1,2
