/* ============================================================================
   Churn Analysis & Customer Intelligence — SQL KPI Library
   Database   : customer_churn.db (SQLite)
   Tables     : db_customer, db_subscription, db_support
   Author     : Aman Kumar
   ============================================================================ */


-- ----------------------------------------------------------------------------
-- 0. Schema check
-- ----------------------------------------------------------------------------
SELECT name FROM sqlite_master WHERE type = 'table';


-- ----------------------------------------------------------------------------
-- 1. Overall Churn Rate & Retention Rate
-- ----------------------------------------------------------------------------
SELECT
    ROUND(100.0 * SUM(CASE WHEN cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                        AS churn_rate_pct,
    ROUND(100.0 - (100.0 * SUM(CASE WHEN cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(*)), 2)                                       AS retention_rate_pct
FROM db_subscription;


-- ----------------------------------------------------------------------------
-- 2. Churn Rate by Plan Type
-- ----------------------------------------------------------------------------
SELECT
    plan_type,
    COUNT(*)                                                     AS total_customers,
    SUM(CASE WHEN cancellation_date IS NOT NULL THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                        AS churn_rate_pct
FROM db_subscription
GROUP BY plan_type
ORDER BY churn_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 3. Churn Rate by Contract Type (Monthly vs Annual)
-- ----------------------------------------------------------------------------
SELECT
    contract_type,
    COUNT(*)                                                     AS total_customers,
    ROUND(100.0 * SUM(CASE WHEN cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                        AS churn_rate_pct
FROM db_subscription
GROUP BY contract_type
ORDER BY churn_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 4. Churn Rate by State (joined with customer table)
-- ----------------------------------------------------------------------------
SELECT
    c.state,
    COUNT(*)                                                     AS total_customers,
    ROUND(100.0 * SUM(CASE WHEN s.cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(*), 2)                                        AS churn_rate_pct
FROM db_subscription s
JOIN db_customer c ON c.customerid = s.customerid
GROUP BY c.state
ORDER BY churn_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 5. ARPU (Average Revenue Per User)
-- ----------------------------------------------------------------------------
SELECT ROUND(AVG(monthly_charges), 2) AS arpu
FROM db_subscription;


-- ----------------------------------------------------------------------------
-- 6. Average Customer Tenure (days) — active customers use today as end date
-- ----------------------------------------------------------------------------
SELECT
    ROUND(AVG(
        JULIANDAY(COALESCE(cancellation_date, DATE('now'))) - JULIANDAY(subscription_start_date)
    ), 1) AS avg_tenure_days
FROM db_subscription;


-- ----------------------------------------------------------------------------
-- 7. Revenue at Risk (MRR tied to churned customers) & % Revenue Loss
-- ----------------------------------------------------------------------------
SELECT
    ROUND(SUM(CASE WHEN cancellation_date IS NOT NULL THEN monthly_charges ELSE 0 END), 2) AS revenue_at_risk,
    ROUND(SUM(monthly_charges), 2)                                                          AS total_mrr,
    ROUND(100.0 * SUM(CASE WHEN cancellation_date IS NOT NULL THEN monthly_charges ELSE 0 END)
          / SUM(monthly_charges), 2)                                                         AS pct_revenue_loss
FROM db_subscription;


-- ----------------------------------------------------------------------------
-- 8. CLTV Lost to Churned Customers
-- ----------------------------------------------------------------------------
SELECT ROUND(SUM(cltv), 2) AS cltv_lost
FROM db_subscription
WHERE cancellation_date IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 9. Support Escalation Rate & Avg Complaints per Customer
-- ----------------------------------------------------------------------------
SELECT
    ROUND(100.0 * SUM(CASE WHEN escalations = 'Y' THEN 1 ELSE 0 END) / COUNT(*), 2) AS escalation_rate_pct
FROM db_support;

SELECT
    ROUND(1.0 * COUNT(*) / COUNT(DISTINCT customerid), 2) AS avg_complaints_per_customer
FROM db_support;


-- ----------------------------------------------------------------------------
-- 10. Escalation → Churn relationship (customers with an escalation vs none)
-- ----------------------------------------------------------------------------
SELECT
    CASE WHEN sup.escalations = 'Y' THEN 'Escalated' ELSE 'Not Escalated' END AS support_status,
    COUNT(DISTINCT s.customerid)                                              AS customers,
    ROUND(100.0 * SUM(CASE WHEN s.cancellation_date IS NOT NULL THEN 1 ELSE 0 END)
          / COUNT(DISTINCT s.customerid), 2)                                  AS churn_rate_pct
FROM db_subscription s
LEFT JOIN db_support sup ON sup.customerid = s.customerid
GROUP BY support_status;


-- ----------------------------------------------------------------------------
-- 11. Churn Risk Tiering (Low / Medium / High) based on churn_score
-- ----------------------------------------------------------------------------
SELECT
    customerid,
    churn_score,
    CASE
        WHEN churn_score < 50 THEN 'Low'
        WHEN churn_score < 70 THEN 'Medium'
        ELSE 'High'
    END AS churn_risk,
    cltv,
    monthly_charges
FROM db_subscription
ORDER BY churn_score DESC;


-- ----------------------------------------------------------------------------
-- 12. High-Risk, High-Value Priority List (for retention outreach)
-- ----------------------------------------------------------------------------
SELECT
    c.customerid,
    c.name,
    s.plan_type,
    s.contract_type,
    s.churn_score,
    s.cltv,
    s.monthly_charges
FROM db_subscription s
JOIN db_customer c ON c.customerid = s.customerid
WHERE s.churn_score >= 70 AND s.cancellation_date IS NULL
ORDER BY s.cltv DESC;
