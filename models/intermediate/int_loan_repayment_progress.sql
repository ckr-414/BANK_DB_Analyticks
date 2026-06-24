-- models/intermediate/int_loan_repayment_progress.sql
{{ config(materialized='table',
    schema=var('intermediate_schema'), database=var('target_database'), tags=['intermediate']) }}
SELECT
    l.loan_id, l.customer_id, l.loan_type,
    l.principal_amount, l.total_repayable, l.total_interest_cost,
    l.status                                             AS loan_status,
    COUNT(p.payment_id)                                  AS payments_made,
    COALESCE(SUM(p.amount_paid),0)                       AS total_paid,
    COALESCE(SUM(p.principal_paid),0)                    AS principal_paid,
    COALESCE(SUM(p.interest_paid),0)                     AS interest_paid,
    COALESCE(MAX(p.remaining_balance),l.principal_amount) AS latest_remaining_balance,
    MIN(p.payment_date)                                  AS first_payment_date,
    MAX(p.payment_date)                                  AS last_payment_date,
    ROUND(100.0*COALESCE(SUM(p.principal_paid),0)
          /NULLIF(l.principal_amount,0),2)               AS pct_principal_repaid,
    CASE WHEN l.status='DEFAULTED' THEN 'DEFAULTED'
         WHEN l.status='PAID_OFF'  THEN 'PAID_OFF'
         WHEN COALESCE(SUM(p.principal_paid),0)/l.principal_amount>0.75 THEN 'HEALTHY'
         WHEN COALESCE(SUM(p.principal_paid),0)/l.principal_amount>0.25 THEN 'ON_TRACK'
         ELSE 'EARLY_STAGE' END                          AS repayment_health,
    -- enter_dt propagated from loan origination date
    {{ audit_columns(enter_from='l.enter_dt', enter_by_from='l.enter_by') }}
FROM {{ ref('stg_loans') }} l
LEFT JOIN {{ ref('stg_loan_payments') }} p ON l.loan_id=p.loan_id
GROUP BY 1,2,3,4,5,6,7, l.enter_dt, l.enter_by
