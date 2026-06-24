-- models/staging/stg_customers.sql
{{ config(materialized='view',
    schema=var('staging_schema'), database=var('target_database'), tags=['staging']) }}
SELECT
    customer_id,
    TRIM(LOWER(first_name))                              AS first_name,
    TRIM(LOWER(last_name))                               AS last_name,
    TRIM(LOWER(email))                                   AS email,
    CAST(dob AS DATE)                                    AS date_of_birth,
    DATEDIFF('year',CAST(dob AS DATE),CURRENT_DATE)      AS age_years,
    UPPER(TRIM(country))                                 AS country,
    UPPER(TRIM(status))                                  AS status,
    CAST(created_at AS TIMESTAMP_NTZ)                    AS created_at,
    CAST(updated_at AS TIMESTAMP_NTZ)                    AS source_updated_at,
    CASE WHEN UPPER(status)='ACTIVE' THEN TRUE ELSE FALSE END AS is_active,
    {{ audit_columns() }}
FROM {{ source('bank_raw','raw_customers') }}
WHERE customer_id IS NOT NULL
