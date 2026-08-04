-- models/incremental/mart_customer_risk_incremental.sql
-- enter_dt from stg_customers (first scoring date preserved).
-- update_dt changes every time risk score is recalculated.
{{ config(
    materialized='incremental', unique_key='customer_id',
    incremental_strategy='merge',
    schema=var('marts_schema'), database=var('target_database'),
    merge_update_columns=[
      'total_balance','account_count','total_debt','defaults',
      'avg_monthly_net','risk_score','risk_band','scored_at',
      'update_dt','update_by','dag_id','dbt_loaded_at','dbt_run_id'
    ],
    tags=['incremental','mart','risk','nightly']
) }}

-- depends_on: {{ ref('stg_transactions') }}
-- depends_on: {{ ref('stg_loan_payments') }}
-- depends_on: {{ ref('stg_loans') }}

{% if is_incremental() %}
WITH changed AS (
    SELECT DISTINCT a.customer_id
    FROM {{ ref('stg_transactions') }} t
    JOIN {{ ref('stg_accounts') }} a ON t.account_id=a.account_id
    WHERE t.dbt_loaded_at >= (SELECT MAX(dbt_loaded_at) FROM {{ this }})
    UNION
    SELECT DISTINCT l.customer_id
    FROM {{ ref('stg_loan_payments') }} p
    JOIN {{ ref('stg_loans') }} l ON p.loan_id=l.loan_id
    WHERE p.dbt_loaded_at >= (SELECT MAX(dbt_loaded_at) FROM {{ this }})
),
{% else %}
WITH changed AS (SELECT DISTINCT customer_id FROM {{ ref('stg_customers') }}),
{% endif %}
scored AS (
    SELECT c.customer_id, c.enter_dt AS cust_enter_dt, c.enter_by AS cust_enter_by,
        SUM(a.current_balance) AS total_balance,
        COUNT(DISTINCT a.account_id) AS account_count,
        COALESCE(SUM(lrp.latest_remaining_balance),0) AS total_debt,
        COUNT(CASE WHEN lrp.repayment_health='DEFAULTED' THEN 1 END) AS defaults,
        COALESCE(AVG(mcf.net_cashflow),0) AS avg_monthly_net
    FROM {{ ref('stg_customers') }} c
    JOIN changed ch ON c.customer_id=ch.customer_id
    LEFT JOIN {{ ref('stg_accounts') }} a ON c.customer_id=a.customer_id
    LEFT JOIN {{ ref('int_loan_repayment_progress') }} lrp ON c.customer_id=lrp.customer_id
    LEFT JOIN {{ ref('int_account_monthly_cashflow') }} mcf ON a.account_id=mcf.account_id
    GROUP BY 1,2,3
)
SELECT
    customer_id, total_balance, account_count, total_debt, defaults, avg_monthly_net,
    LEAST(100,GREATEST(0,
        (defaults*30)
        +CASE WHEN total_debt/NULLIF(total_balance,0)>3 THEN 25 ELSE 0 END
        +CASE WHEN avg_monthly_net<0 THEN 20 ELSE 0 END
        +CASE WHEN total_balance<1000 THEN 15 ELSE 0 END))  AS risk_score,
    CASE WHEN defaults>0 THEN 'VERY_HIGH'
         WHEN total_debt/NULLIF(total_balance,0)>3 THEN 'HIGH'
         WHEN avg_monthly_net<0 THEN 'MEDIUM' ELSE 'LOW' END AS risk_band,
    CURRENT_TIMESTAMP()                                       AS scored_at,
    {{ audit_columns(enter_from='cust_enter_dt', enter_by_from='cust_enter_by') }}
FROM scored
