-- models/marts/mart_loan_portfolio_health.sql
{{ config(materialized='table',
    schema=var('marts_schema'), database=var('target_database'), tags=['mart','nightly']) }}
SELECT
    loan_type,
    COUNT(loan_id)                                       AS total_loans,
    SUM(principal_amount)                                AS total_principal,
    SUM(principal_paid)                                  AS total_recovered,
    SUM(latest_remaining_balance)                        AS total_outstanding,
    SUM(interest_paid)                                   AS total_interest_earned,
    AVG(pct_principal_repaid)                            AS avg_pct_repaid,
    COUNT(CASE WHEN repayment_health='PAID_OFF'  THEN 1 END) AS paid_off_count,
    COUNT(CASE WHEN repayment_health='HEALTHY'   THEN 1 END) AS healthy_count,
    COUNT(CASE WHEN repayment_health='DEFAULTED' THEN 1 END) AS defaulted_count,
    ROUND(100.0*COUNT(CASE WHEN repayment_health='DEFAULTED' THEN 1 END)
          /NULLIF(COUNT(loan_id),0),2)                   AS default_rate_pct,
    {{ audit_columns(enter_from='MIN(enter_dt)', enter_by_from='MIN(enter_by)') }}
FROM {{ ref('int_loan_repayment_progress') }}
GROUP BY 1 ORDER BY total_principal DESC
