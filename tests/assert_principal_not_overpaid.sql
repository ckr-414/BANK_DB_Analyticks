-- tests/assert_principal_not_overpaid.sql
SELECT loan_id, principal_amount, SUM(principal_paid) AS paid,
       SUM(principal_paid)-principal_amount AS overpaid_by
FROM {{ ref('int_loan_repayment_progress') }}
WHERE principal_paid > principal_amount * 1.01
GROUP BY 1,2;
