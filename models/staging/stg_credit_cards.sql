-- models/staging/stg_credit_cards.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    card_id, customer_id, credit_limit, current_balance,
    ROUND(100.0*current_balance/NULLIF(credit_limit,0),2) AS utilisation_pct,
    CAST(issued_at   AS DATE)                            AS issued_date,
    CAST(expiry_date AS DATE)                            AS expiry_date,
    UPPER(status)                                        AS status,
    CAST(updated_at  AS TIMESTAMP_NTZ)                   AS source_updated_at,
    CASE WHEN current_balance/NULLIF(credit_limit,0)>0.9 THEN 'CRITICAL'
         WHEN current_balance/NULLIF(credit_limit,0)>0.6 THEN 'HIGH'
         WHEN current_balance/NULLIF(credit_limit,0)>0.3 THEN 'MEDIUM'
         ELSE 'LOW' END                                  AS util_risk_tier,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_credit_cards') }}
WHERE card_id IS NOT NULL
