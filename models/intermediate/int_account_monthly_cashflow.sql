-- models/intermediate/int_account_monthly_cashflow.sql
{{ config(materialized='table',
    schema=var('intermediate_schema'), database=var('target_database'), tags=['intermediate']) }}
SELECT
    account_id, transaction_month,
    COUNT(transaction_id)                                AS transaction_count,
    SUM(CASE WHEN direction='CREDIT' THEN gross_amount ELSE 0 END) AS total_credits,
    SUM(CASE WHEN direction='DEBIT'  THEN gross_amount ELSE 0 END) AS total_debits,
    SUM(signed_amount)                                   AS net_cashflow,
    AVG(gross_amount)                                    AS avg_transaction_size,
    MAX(gross_amount)                                    AS largest_transaction,
    COUNT(DISTINCT category)                             AS unique_categories,
    -- enter_dt = earliest transaction enter_dt in that month
    {{ audit_columns(enter_from='MIN(enter_dt)', enter_by_from='MIN(enter_by)') }}
FROM {{ ref('stg_transactions') }}
GROUP BY 1,2
