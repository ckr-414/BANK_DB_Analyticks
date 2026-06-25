-- snapshots/account_balance_snapshot.sql
-- SCD Type 2: balance changes over time (end-of-day)
{% snapshot account_balance_snapshot %}
{{ config(
    target_schema=var('snapshots_schema'), target_database=var('target_database'),
    unique_key='account_id', strategy='timestamp', updated_at='dbt_loaded_at',
    invalidate_hard_deletes=True
) }}
SELECT account_id, customer_id, account_type, currency,
       current_balance, status, is_open, opened_date, closed_date,
       enter_dt, enter_by, update_dt, update_by, dag_id, dbt_loaded_at
FROM {{ ref('stg_accounts') }}
{% endsnapshot %}
-- Balance trend:
-- SELECT account_id, dbt_valid_from, current_balance,
--   current_balance - LAG(current_balance) OVER (PARTITION BY account_id ORDER BY dbt_valid_from) AS delta
-- FROM BANK_DB.SNAPSHOTS.account_balance_snapshot WHERE account_id='A001'
