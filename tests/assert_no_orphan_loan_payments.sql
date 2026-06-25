-- tests/assert_no_orphan_loan_payments.sql
SELECT p.payment_id, p.loan_id
FROM {{ ref('stg_loan_payments') }} p
LEFT JOIN {{ ref('stg_loans') }} l ON p.loan_id=l.loan_id
WHERE l.loan_id IS NULL;
