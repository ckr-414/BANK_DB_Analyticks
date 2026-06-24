-- models/staging/stg_accounts.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    account_id, customer_id,
    UPPER(account_type)                                  AS account_type,
    UPPER(currency)                                      AS currency,
    CAST(opened_at AS DATE)                              AS opened_date,
    CAST(closed_at AS DATE)                              AS closed_date,
    COALESCE(balance,0.00)                               AS current_balance,
    UPPER(status)                                        AS status,
    CAST(updated_at AS TIMESTAMP_NTZ)                    AS source_updated_at,
    CASE WHEN closed_at IS NULL THEN TRUE ELSE FALSE END AS is_open,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_accounts') }}
WHERE account_id IS NOT NULL
