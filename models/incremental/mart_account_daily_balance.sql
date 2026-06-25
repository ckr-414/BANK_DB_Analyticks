-- models/incremental/mart_account_daily_balance.sql
-- enter_dt = CAST(balance_date) — stable even when rows are deleted+re-inserted.
{{ config(
    materialized='incremental',
    unique_key=['account_id','balance_date'],
    incremental_strategy='delete+insert',
    schema=var('marts_schema'), database=var('target_database'),
    on_schema_change='sync_all_columns',
    cluster_by=['balance_date','account_id'], tags=['incremental','mart','nightly']
) }}
WITH daily AS (
    SELECT
        account_id, transaction_date                     AS balance_date,
        SUM(CASE WHEN direction='CREDIT' THEN gross_amount ELSE 0 END) AS day_credits,
        SUM(CASE WHEN direction='DEBIT'  THEN gross_amount ELSE 0 END) AS day_debits,
        SUM(signed_amount)                               AS day_net,
        COUNT(transaction_id)                            AS day_txn_count,
        MIN(enter_dt)                                    AS src_enter_dt,
        MIN(enter_by)                                    AS src_enter_by
    FROM {{ ref('stg_transactions') }}
    {{ incremental_watermark('transaction_date', lookback_days=7) }}
    GROUP BY 1,2
)
SELECT
    MD5(a.account_id||'::'||TO_VARCHAR(d.balance_date)) AS account_date_key,
    a.account_id, a.customer_id, a.account_type, a.currency,
    d.balance_date, DATE_TRUNC('MONTH',d.balance_date)  AS balance_month,
    COALESCE(d.day_credits,0)                            AS day_credits,
    COALESCE(d.day_debits,0)                             AS day_debits,
    COALESCE(d.day_net,0)                                AS day_net_flow,
    COALESCE(d.day_txn_count,0)                          AS day_transaction_count,
    {{ audit_columns(enter_from='CAST(d.balance_date AS TIMESTAMP_NTZ)',
                     enter_by_from='d.src_enter_by') }}
FROM {{ ref('stg_accounts') }} a
JOIN daily d ON a.account_id=d.account_id
