-- models/incremental/int_transactions_incremental.sql
-- enter_dt set ONCE on first append insert — row is never revisited.
{{ config(
    materialized='incremental', unique_key='transaction_id',
    incremental_strategy='append',
    schema=var('intermediate_schema'), database=var('target_database'),
    on_schema_change='sync_all_columns',
    cluster_by=['transaction_month'], tags=['incremental','hourly']
) }}
SELECT
    t.transaction_id, t.account_id, a.customer_id,
    t.transaction_date, t.transaction_month,
    t.direction, t.gross_amount, t.signed_amount,
    t.category, t.merchant_name, t.status, t.amount_tier,
    DAYOFWEEK(t.transaction_date) AS day_of_week,
    hour(cast(t.transaction_date as timestamp))  AS hour_of_day,
    {{ audit_columns() }}
FROM {{ ref('stg_transactions') }} t
JOIN {{ ref('stg_accounts') }} a ON t.account_id=a.account_id
{{ incremental_watermark('t.transaction_date', lookback_days=0) }}
