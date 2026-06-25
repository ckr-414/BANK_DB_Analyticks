-- snapshots/credit_card_limit_snapshot.sql
-- SCD Type 2: credit limit raises, card status changes
{% snapshot credit_card_limit_snapshot %}
{{ config(
    target_schema=var('snapshots_schema'), target_database=var('target_database'),
    unique_key='card_id', strategy='check',
    check_cols=['credit_limit','status','current_balance'],
    invalidate_hard_deletes=True
) }}
SELECT card_id, customer_id, credit_limit, current_balance,
       utilisation_pct, issued_date, expiry_date, status,
       enter_dt, enter_by, update_dt, update_by, dag_id, dbt_run_id
FROM {{ ref('stg_credit_cards') }}
{% endsnapshot %}
-- Limit history:
-- SELECT card_id, credit_limit,
--   LAG(credit_limit) OVER (PARTITION BY card_id ORDER BY dbt_valid_from) AS prev_limit,
--   credit_limit - LAG(credit_limit) OVER (...) AS delta, dbt_valid_from AS effective_from
-- FROM BANK_DB.SNAPSHOTS.credit_card_limit_snapshot ORDER BY card_id, dbt_valid_from
