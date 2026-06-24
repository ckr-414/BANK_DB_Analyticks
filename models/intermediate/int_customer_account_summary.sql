-- models/intermediate/int_customer_account_summary.sql
{{ config(materialized='table',
    schema=var('intermediate_schema'), database=var('target_database'), tags=['intermediate']) }}
SELECT
    c.customer_id, c.first_name, c.last_name,
    c.country, c.age_years, c.is_active,
    COUNT(a.account_id)                                  AS total_accounts,
    COUNT(CASE WHEN a.account_type='SAVINGS'    THEN 1 END) AS savings_accounts,
    COUNT(CASE WHEN a.account_type='CHECKING'   THEN 1 END) AS checking_accounts,
    COUNT(CASE WHEN a.account_type='INVESTMENT' THEN 1 END) AS investment_accounts,
    COUNT(CASE WHEN a.is_open=TRUE              THEN 1 END) AS open_accounts,
    COALESCE(SUM(a.current_balance),0)                   AS total_balance,
    COALESCE(AVG(a.current_balance),0)                   AS avg_account_balance,
    COALESCE(MAX(a.current_balance),0)                   AS max_account_balance,
    MIN(a.opened_date)                                   AS earliest_account_date,
    -- enter_dt propagated from customer origin date
    {{ audit_columns(enter_from='c.enter_dt', enter_by_from='c.enter_by') }}
FROM {{ ref('stg_customers') }} c
LEFT JOIN {{ ref('stg_accounts') }} a ON c.customer_id=a.customer_id
GROUP BY 1,2,3,4,5,6, c.enter_dt, c.enter_by
