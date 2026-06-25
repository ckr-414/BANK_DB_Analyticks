-- tests/assert_update_dt_gte_enter_dt.sql
SELECT 'int_customer_account_summary' AS model, COUNT(*) AS violations
FROM {{ ref('int_customer_account_summary') }}
WHERE update_dt < enter_dt
HAVING COUNT(*)>0
UNION ALL
SELECT 'mart_customer_360', COUNT(*)
FROM {{ ref('mart_customer_360') }}
WHERE update_dt < enter_dt
HAVING COUNT(*)>0;
