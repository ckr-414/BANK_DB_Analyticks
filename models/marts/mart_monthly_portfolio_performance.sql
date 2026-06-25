-- models/marts/mart_monthly_portfolio_performance.sql
{{ config(materialized='table',
    schema=var('marts_schema'), database=var('target_database'), tags=['mart','nightly']) }}
SELECT
    mcf.transaction_month,
    COUNT(DISTINCT sa.customer_id)                       AS active_customers,
    COUNT(DISTINCT mcf.account_id)                       AS active_accounts,
    SUM(mcf.total_credits)                               AS total_deposits,
    SUM(mcf.total_debits)                                AS total_withdrawals,
    SUM(mcf.net_cashflow)                                AS net_portfolio_flow,
    SUM(mcf.transaction_count)                           AS total_transactions,
    AVG(mcf.avg_transaction_size)                        AS avg_txn_value,
    SUM(mcf.net_cashflow)
        - LAG(SUM(mcf.net_cashflow)) OVER (ORDER BY mcf.transaction_month) AS mom_delta,
    ROUND(100.0*(SUM(mcf.net_cashflow)
        - LAG(SUM(mcf.net_cashflow)) OVER (ORDER BY mcf.transaction_month))
        / NULLIF(LAG(SUM(mcf.net_cashflow)) OVER (ORDER BY mcf.transaction_month),0),2)
                                                         AS mom_pct_change,
    {{ audit_columns(enter_from='MIN(mcf.enter_dt)', enter_by_from='MIN(mcf.enter_by)') }}
FROM {{ ref('int_account_monthly_cashflow') }} mcf
JOIN {{ ref('stg_accounts') }} sa ON mcf.account_id=sa.account_id
GROUP BY 1 ORDER BY 1
