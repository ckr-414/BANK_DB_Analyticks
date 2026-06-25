-- snapshots/customers_snapshot.sql
-- SCD Type 2: status, email, country changes → new row per change
{% snapshot customers_snapshot %}
{{ config(
    target_schema=var('snapshots_schema'), target_database=var('target_database'),
    unique_key='customer_id', strategy='check',
    check_cols=['status','email','country'],
    invalidate_hard_deletes=True
) }}
SELECT customer_id, first_name, last_name, email, date_of_birth,
       country, status, is_active, created_at,
       enter_dt, enter_by, update_dt, update_by, dag_id, dbt_run_id
FROM {{ ref('stg_customers') }}
{% endsnapshot %}
-- dbt adds: dbt_scd_id, dbt_valid_from, dbt_valid_to, dbt_updated_at, dbt_is_deleted
-- Current rows: WHERE dbt_valid_to IS NULL
-- Point-in-time: WHERE dbt_valid_from<='2023-06-01' AND (dbt_valid_to>'2023-06-01' OR dbt_valid_to IS NULL)
