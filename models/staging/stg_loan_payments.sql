-- models/staging/stg_loan_payments.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    payment_id, loan_id,
    CAST(payment_date AS DATE)                           AS payment_date,
    amount_paid, principal_paid, interest_paid, remaining_balance,
    CASE WHEN interest_paid/NULLIF(amount_paid,0)>0.5
         THEN TRUE ELSE FALSE END                        AS is_interest_heavy,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_loan_payments') }}
WHERE payment_id IS NOT NULL AND amount_paid > 0
