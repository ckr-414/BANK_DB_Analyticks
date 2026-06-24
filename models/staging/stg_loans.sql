-- models/staging/stg_loans.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    loan_id, customer_id, UPPER(loan_type) AS loan_type,
    principal_amount, interest_rate, term_months,
    CAST(start_date AS DATE) AS start_date,
    CAST(end_date   AS DATE) AS end_date,
    monthly_payment, UPPER(status) AS status,
    CAST(updated_at AS TIMESTAMP_NTZ)                    AS source_updated_at,
    (monthly_payment * term_months)                      AS total_repayable,
    (monthly_payment * term_months) - principal_amount   AS total_interest_cost,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_loans') }}
WHERE loan_id IS NOT NULL
