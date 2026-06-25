-- snapshots/loan_status_snapshot.sql
-- SCD Type 2: tracks loan lifecycle + interest rate renegotiations
-- check_cols includes interest_rate → fires on refinance (Run 3 test)
{% snapshot loan_status_snapshot %}
{{ config(
    target_schema=var('snapshots_schema'), target_database=var('target_database'),
    unique_key='loan_id', strategy='check',
    check_cols=['status','interest_rate'],
    invalidate_hard_deletes=True
) }}
SELECT loan_id, customer_id, loan_type, principal_amount,
       interest_rate, term_months, monthly_payment, status,
       total_repayable, total_interest_cost,
       enter_dt, enter_by, update_dt, update_by, dag_id, dbt_run_id
FROM {{ ref('stg_loans') }}
{% endsnapshot %}
-- Exact default date:
-- SELECT loan_id, customer_id, dbt_valid_from AS defaulted_at
-- FROM BANK_DB.SNAPSHOTS.loan_status_snapshot WHERE status='defaulted'
