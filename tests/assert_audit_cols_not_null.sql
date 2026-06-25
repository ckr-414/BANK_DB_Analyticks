-- tests/assert_audit_cols_not_null.sql
-- enter_dt, enter_by, update_dt, update_by, dag_id must all be non-null
SELECT 'mart_customer_360' AS model, COUNT(*) AS null_rows
FROM {{ ref('mart_customer_360') }}
WHERE enter_dt IS NULL OR enter_by IS NULL
   OR update_dt IS NULL OR update_by IS NULL OR dag_id IS NULL
HAVING COUNT(*)>0
UNION ALL
SELECT 'mart_loan_portfolio_health', COUNT(*)
FROM {{ ref('mart_loan_portfolio_health') }}
WHERE enter_dt IS NULL OR dag_id IS NULL
HAVING COUNT(*)>0;
