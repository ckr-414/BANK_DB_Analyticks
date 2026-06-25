-- models/incremental/int_loan_payments_incremental.sql
-- enter_dt/enter_by EXCLUDED from merge_update_columns → preserved forever.
-- update_dt/update_by/dag_id refreshed on every correction.
{{ config(
    materialized='incremental', unique_key='payment_id',
    incremental_strategy='merge',
    schema=var('intermediate_schema'), database=var('target_database'),
    merge_update_columns=[
      'amount_paid','principal_paid','interest_paid',
      'remaining_balance','is_interest_heavy','cumulative_pct_paid',
      'update_dt','update_by','dag_id','dbt_loaded_at','dbt_run_id'
    ],
    on_schema_change='sync_all_columns', tags=['incremental','payments']
) }}
SELECT
    p.payment_id, p.loan_id, l.customer_id, l.loan_type,
    p.payment_date, p.amount_paid, p.principal_paid,
    p.interest_paid, p.remaining_balance, p.is_interest_heavy,
    ROUND(100.0*(l.principal_amount-p.remaining_balance)
          /NULLIF(l.principal_amount,0),2)               AS cumulative_pct_paid,
    {{ audit_columns() }}
FROM {{ ref('stg_loan_payments') }} p
JOIN {{ ref('stg_loans') }} l ON p.loan_id=l.loan_id
{{ incremental_watermark('p.payment_date', lookback_days=3) }}
