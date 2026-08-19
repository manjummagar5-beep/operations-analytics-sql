-- ============================================================
-- PAYMENTS & FINANCIAL OPERATIONS ANALYSIS
-- Independent portfolio project using synthetic payments data
-- Tools: SQL, SQLite, DB Browser for SQLite
-- ============================================================

-- ============================================================
-- SECTION 1: TRANSACTION PERFORMANCE
-- ============================================================

-- Business Question 1:
-- What is the transaction volume, total value and average value by currency?
SELECT
    currency,
    COUNT(*) AS transaction_count,
    ROUND(SUM(amount), 2) AS total_transaction_value,
    ROUND(AVG(amount), 2) AS average_transaction_amount
FROM transactions
GROUP BY currency
ORDER BY currency;

-- Business Question 2:
-- How many transactions are Successful, Failed or Pending,
-- and what is the value in each status?
SELECT
    status,
    COUNT(*) AS transaction_count,
    ROUND(SUM(amount), 2) AS transaction_value
FROM transactions
GROUP BY status
ORDER BY transaction_count DESC;

-- Business Question 3:
-- Which payment methods have the highest success and failure rates?
SELECT
    payment_method,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'Successful' THEN 1 ELSE 0 END) AS successful_transactions,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed_transactions,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'Successful' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS success_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS failure_rate_pct
FROM transactions
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;

-- ============================================================
-- SECTION 2: OPERATIONAL EXCEPTIONS
-- ============================================================

-- Business Question 4:
-- What are the most common transaction failure reasons?
SELECT
    failure_reason,
    COUNT(*) AS failure_count
FROM transactions
WHERE status = 'Failed'
GROUP BY failure_reason
ORDER BY failure_count DESC;

-- Business Question 5:
-- Which high-value failed transactions should be reviewed first?
SELECT
    transaction_id,
    customer_id,
    transaction_date,
    amount,
    currency,
    payment_method,
    failure_reason
FROM transactions
WHERE status = 'Failed'
  AND amount >= 1000
ORDER BY amount DESC;

-- Business Question 6:
-- How can failed transactions be classified by operational priority?
SELECT
    transaction_id,
    customer_id,
    amount,
    currency,
    payment_method,
    failure_reason,
    CASE
        WHEN status = 'Failed' AND amount >= 1500 THEN 'High Priority'
        WHEN status = 'Failed' AND amount >= 750 THEN 'Medium Priority'
        WHEN status = 'Failed' THEN 'Low Priority'
        ELSE 'No Exception'
    END AS priority_level
FROM transactions
WHERE status = 'Failed'
ORDER BY amount DESC;

-- ============================================================
-- SECTION 3: CUSTOMER / CLIENT ANALYSIS
-- ============================================================

-- Business Question 7:
-- Which customers experienced repeated failed transactions?
SELECT
    c.customer_id,
    c.customer_type,
    c.segment,
    c.country,
    COUNT(*) AS failed_transactions
FROM customers c
INNER JOIN transactions t
    ON c.customer_id = t.customer_id
WHERE t.status = 'Failed'
GROUP BY
    c.customer_id,
    c.customer_type,
    c.segment,
    c.country
HAVING COUNT(*) > 1
ORDER BY failed_transactions DESC;

-- Business Question 8:
-- Which customer segments have the highest transaction failure rates?
SELECT
    c.segment,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN t.status = 'Failed' THEN 1 ELSE 0 END) AS failed_transactions,
    ROUND(
        100.0 * SUM(CASE WHEN t.status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS failure_rate_pct
FROM customers c
INNER JOIN transactions t
    ON c.customer_id = t.customer_id
GROUP BY c.segment
ORDER BY failure_rate_pct DESC;

-- ============================================================
-- SECTION 4: FINANCIAL RECONCILIATION
-- ============================================================

-- Business Question 9:
-- Which transactions have a mismatch between expected and settled amounts?
SELECT
    t.transaction_id,
    t.customer_id,
    t.amount AS transaction_amount,
    t.currency,
    r.expected_amount,
    r.settled_amount,
    ROUND(r.expected_amount - r.settled_amount, 2) AS difference,
    r.settlement_status
FROM transactions t
INNER JOIN reconciliation r
    ON t.transaction_id = r.transaction_id
WHERE r.expected_amount != r.settled_amount
ORDER BY ABS(r.expected_amount - r.settled_amount) DESC;

-- Business Question 10:
-- Which successful or pending transactions have no reconciliation record?
SELECT
    t.transaction_id,
    t.customer_id,
    t.transaction_date,
    t.amount,
    t.currency,
    t.status
FROM transactions t
LEFT JOIN reconciliation r
    ON t.transaction_id = r.transaction_id
WHERE t.status IN ('Successful', 'Pending')
  AND r.transaction_id IS NULL
ORDER BY t.amount DESC;

-- Business Question 11:
-- Which unsettled transactions represent the largest outstanding items?
SELECT
    t.transaction_id,
    t.customer_id,
    t.amount,
    t.currency,
    t.payment_method,
    r.expected_amount,
    r.settled_amount,
    r.settlement_status,
    r.settlement_date
FROM transactions t
INNER JOIN reconciliation r
    ON t.transaction_id = r.transaction_id
WHERE r.settlement_status = 'Unsettled'
ORDER BY t.amount DESC;

-- ============================================================
-- SECTION 5: TREND ANALYSIS
-- ============================================================

-- Business Question 12:
-- How did transaction volume and failure rates change month by month?
SELECT
    strftime('%Y-%m', transaction_date) AS month,
    COUNT(*) AS transaction_volume,
    ROUND(SUM(amount), 2) AS nominal_transaction_value,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed_transactions,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS failure_rate_pct
FROM transactions
GROUP BY strftime('%Y-%m', transaction_date)
ORDER BY month;

-- Business Question 13 (Advanced):
-- What is the month-on-month change in transaction volume?
WITH monthly_transactions AS (
    SELECT
        strftime('%Y-%m', transaction_date) AS month,
        COUNT(*) AS transaction_volume
    FROM transactions
    GROUP BY strftime('%Y-%m', transaction_date)
)
SELECT
    month,
    transaction_volume,
    LAG(transaction_volume) OVER (ORDER BY month) AS previous_month_volume,
    ROUND(
        100.0 * (
            transaction_volume -
            LAG(transaction_volume) OVER (ORDER BY month)
        ) / LAG(transaction_volume) OVER (ORDER BY month),
        2
    ) AS month_on_month_change_pct
FROM monthly_transactions
ORDER BY month;

-- ============================================================
-- SECTION 6: FINAL FINDING CHECKS
-- ============================================================

-- Finding Check 1:
-- Payment method failure rates.
SELECT
    payment_method,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) AS failed_transactions,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS failure_rate_pct
FROM transactions
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;

-- Finding Check 2:
-- Count customers with repeated failures.
SELECT COUNT(*) AS customers_with_repeated_failures
FROM (
    SELECT customer_id
    FROM transactions
    WHERE status = 'Failed'
      AND customer_id IN (SELECT customer_id FROM customers)
    GROUP BY customer_id
    HAVING COUNT(*) > 1
);

-- Finding Check 3:
-- Reconciliation exceptions by status.
SELECT
    settlement_status,
    COUNT(*) AS exception_count
FROM reconciliation
WHERE expected_amount != settled_amount
GROUP BY settlement_status
ORDER BY exception_count DESC;

-- Finding Check 4:
-- Count eligible transactions with no reconciliation record.
SELECT COUNT(*) AS missing_reconciliation_records
FROM transactions t
LEFT JOIN reconciliation r
    ON t.transaction_id = r.transaction_id
WHERE t.status IN ('Successful', 'Pending')
  AND r.transaction_id IS NULL;

-- ============================================================
-- END OF ANALYSIS
-- ============================================================
