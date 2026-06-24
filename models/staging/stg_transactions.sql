-- models/staging/stg_transactions.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    transaction_id, account_id,
    CAST(transaction_date AS DATE)                       AS transaction_date,
    DATE_TRUNC('MONTH',CAST(transaction_date AS DATE))   AS transaction_month,
    UPPER(direction)                                     AS direction,
    ABS(amount)                                          AS gross_amount,
    CASE WHEN UPPER(direction)='CREDIT' THEN  ABS(amount)
         WHEN UPPER(direction)='DEBIT'  THEN -ABS(amount) END AS signed_amount,
    UPPER(category)                                      AS category,
    merchant_name, UPPER(status)                         AS status,
    CASE WHEN ABS(amount)>=5000 THEN 'HIGH'
         WHEN ABS(amount)>=500  THEN 'MEDIUM' ELSE 'LOW' END  AS amount_tier,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_transactions') }}
WHERE UPPER(status) != 'FAILED' AND amount > 0
