-- models/marts/mart_customer_360.sql
{{ config(materialized='table',
    schema=var('marts_schema'), database=var('target_database'), tags=['mart','nightly']) }}
SELECT
    cas.customer_id, cas.first_name, cas.last_name,
    cas.country, cas.age_years, cas.is_active,
    cas.total_accounts, cas.open_accounts,
    cas.total_balance, cas.avg_account_balance,
    COALESCE(SUM(mcf.total_credits),0)                   AS annual_credits,
    COALESCE(SUM(mcf.total_debits),0)                    AS annual_debits,
    COALESCE(SUM(mcf.net_cashflow),0)                    AS annual_net_cashflow,
    COALESCE(AVG(mcf.net_cashflow),0)                    AS avg_monthly_cashflow,
    COUNT(DISTINCT lrp.loan_id)                          AS total_loans,
    COALESCE(SUM(lrp.principal_amount),0)                AS total_loan_principal,
    COALESCE(SUM(lrp.latest_remaining_balance),0)        AS total_outstanding_debt,
    COUNT(CASE WHEN lrp.repayment_health='DEFAULTED' THEN 1 END) AS defaulted_loans,
    COALESCE(SUM(cc.credit_limit),0)                     AS total_credit_limit,
    COALESCE(SUM(cc.current_balance),0)                  AS total_card_balance,
    CASE WHEN COUNT(CASE WHEN lrp.repayment_health='DEFAULTED' THEN 1 END)>0
              THEN 'HIGH_RISK'
         WHEN COALESCE(SUM(lrp.latest_remaining_balance),0)
              /NULLIF(cas.total_balance,0)>3              THEN 'LEVERAGED'
         WHEN COALESCE(SUM(lrp.latest_remaining_balance),0)
              /NULLIF(cas.total_balance,0)>1              THEN 'MODERATE_RISK'
         ELSE 'LOW_RISK' END                             AS risk_segment,
    CASE WHEN cas.total_balance>=500000 THEN 'PLATINUM'
         WHEN cas.total_balance>=100000 THEN 'GOLD'
         WHEN cas.total_balance>=10000  THEN 'SILVER'
         ELSE 'STANDARD' END                             AS value_tier,
    -- enter_dt end-to-end from customer origin
    {{ audit_columns(enter_from='cas.enter_dt', enter_by_from='cas.enter_by') }}
FROM {{ ref('int_customer_account_summary') }} cas
LEFT JOIN {{ ref('stg_accounts') }} sa ON cas.customer_id=sa.customer_id
LEFT JOIN {{ ref('int_account_monthly_cashflow') }} mcf
    ON sa.account_id=mcf.account_id
    AND mcf.transaction_month>=DATE_TRUNC('MONTH',DATEADD('MONTH',-12,CURRENT_DATE))
LEFT JOIN {{ ref('int_loan_repayment_progress') }} lrp ON cas.customer_id=lrp.customer_id
LEFT JOIN {{ ref('stg_credit_cards') }} cc ON cas.customer_id=cc.customer_id
GROUP BY 1,2,3,4,5,6,7,8,9,10, cas.enter_dt, cas.enter_by
