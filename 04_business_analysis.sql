-- =====================================================================
-- Olist E-Commerce SQL Analysis
-- 04 - Business questions
-- Scope: delivered orders, Jan 2017 - Aug 2018 (complete months).
-- Currency: Brazilian Real (BRL).
-- =====================================================================

-- A reusable view: one row per delivered order with its revenue.
CREATE OR REPLACE VIEW v_delivered_orders AS
SELECT o.order_id,
       o.customer_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_purchase_timestamp,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       SUM(oi.price)                    AS product_revenue,
       SUM(oi.freight_value)            AS freight,
       SUM(oi.price + oi.freight_value) AS order_value,
       COUNT(*)                         AS items
FROM orders o
JOIN customers   c  ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY o.order_id, o.customer_id, c.customer_unique_id, c.customer_state,
         o.order_purchase_timestamp, o.order_delivered_customer_date,
         o.order_estimated_delivery_date;


-- ---------------------------------------------------------------------
-- SECTION A: Sales overview
-- ---------------------------------------------------------------------

-- Q1. Headline KPIs
SELECT COUNT(*)                                 AS orders,
       COUNT(DISTINCT customer_unique_id)       AS customers,
       ROUND(SUM(order_value), 0)               AS total_revenue,
       ROUND(AVG(order_value), 2)               AS avg_order_value,
       ROUND(AVG(items), 2)                     AS avg_items_per_order
FROM v_delivered_orders;

-- Q2. Monthly revenue with month-over-month growth (window function: LAG)
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           COUNT(*)                   AS orders,
           ROUND(SUM(order_value), 0) AS revenue
    FROM v_delivered_orders
    GROUP BY 1
)
SELECT month,
       orders,
       revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1)               AS mom_growth_pct,
       ROUND(AVG(revenue) OVER (ORDER BY month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0)
                                                                    AS rolling_3m_avg
FROM monthly
ORDER BY month;

-- Q3. Year-over-year: Jan-Aug 2017 vs Jan-Aug 2018
SELECT EXTRACT(YEAR FROM order_purchase_timestamp)::int AS year,
       COUNT(*)                   AS orders,
       ROUND(SUM(order_value), 0) AS revenue,
       ROUND(AVG(order_value), 2) AS avg_order_value
FROM v_delivered_orders
WHERE EXTRACT(MONTH FROM order_purchase_timestamp) BETWEEN 1 AND 8
GROUP BY 1
ORDER BY 1;

-- Q4. When do customers shop? Orders by weekday and hour
SELECT TO_CHAR(order_purchase_timestamp, 'ID-Dy') AS weekday,
       COUNT(*)                                   AS orders
FROM v_delivered_orders
GROUP BY 1
ORDER BY 1;

SELECT EXTRACT(HOUR FROM order_purchase_timestamp)::int AS hour,
       COUNT(*) AS orders
FROM v_delivered_orders
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------
-- SECTION B: Products & categories
-- ---------------------------------------------------------------------

-- Q5. Top 10 categories by revenue and their share of total (CTE + window)
WITH cat AS (
    SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
           COUNT(DISTINCT oi.order_id) AS orders,
           SUM(oi.price)               AS revenue
    FROM order_items oi
    JOIN v_delivered_orders d       ON d.order_id = oi.order_id
    JOIN products p                 ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY 1
)
SELECT category,
       orders,
       ROUND(revenue, 0)                                          AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)           AS revenue_share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
             / SUM(revenue) OVER (), 1)                           AS cumulative_share_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- Q6. Best-selling product in each of the top 5 categories (RANK / PARTITION BY)
WITH product_sales AS (
    SELECT t.product_category_name_english AS category,
           oi.product_id,
           COUNT(*)      AS units_sold,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN v_delivered_orders d        ON d.order_id = oi.order_id
    JOIN products p                  ON p.product_id = oi.product_id
    JOIN category_translation t      ON t.product_category_name = p.product_category_name
    GROUP BY 1, 2
), ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category,
           SUM(revenue) OVER (PARTITION BY category)                 AS category_revenue
    FROM product_sales
)
SELECT category, product_id, units_sold, ROUND(revenue, 0) AS revenue
FROM ranked
WHERE rank_in_category = 1
ORDER BY category_revenue DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- SECTION C: Customers
-- ---------------------------------------------------------------------

-- Q7. Repeat purchase rate: how many customers ordered more than once?
WITH per_customer AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM v_delivered_orders
    GROUP BY 1
)
SELECT CASE WHEN orders = 1 THEN '1 order'
            WHEN orders = 2 THEN '2 orders'
            ELSE '3+ orders' END                              AS segment,
       COUNT(*)                                              AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct
FROM per_customer
GROUP BY 1
ORDER BY 1;

-- Q8. Revenue by state: top 10
SELECT customer_state,
       COUNT(*)                                                  AS orders,
       ROUND(SUM(order_value), 0)                                AS revenue,
       ROUND(100.0 * SUM(order_value) / SUM(SUM(order_value)) OVER (), 1) AS revenue_share_pct,
       ROUND(AVG(order_value), 2)                                AS avg_order_value,
       ROUND(AVG(freight), 2)                                    AS avg_freight
FROM v_delivered_orders
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- Q9. RFM segmentation (Recency, Frequency, Monetary) with NTILE
--     Reference date = day after the last order in the data.
WITH rfm_base AS (
    SELECT customer_unique_id,
           (SELECT MAX(order_purchase_timestamp) FROM v_delivered_orders)::date + 1
               - MAX(order_purchase_timestamp)::date AS recency_days,
           COUNT(*)                                  AS frequency,
           SUM(order_value)                          AS monetary
    FROM v_delivered_orders
    GROUP BY 1
), rfm_scores AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- recent = 5
           NTILE(5) OVER (ORDER BY monetary)          AS m_score   -- high spend = 5
    FROM rfm_base
), segments AS (
    SELECT *,
           CASE
               WHEN frequency >= 2 AND m_score >= 4 THEN 'Champions'
               WHEN frequency >= 2                  THEN 'Loyal'
               WHEN r_score >= 4 AND m_score >= 4   THEN 'New high-value'
               WHEN r_score >= 4                    THEN 'New low-value'
               WHEN m_score >= 4                    THEN 'At risk (high-value)'
               ELSE 'Lost / hibernating'
           END AS segment
    FROM rfm_scores
)
SELECT segment,
       COUNT(*)                                                    AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_customers,
       ROUND(SUM(monetary), 0)                                     AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
       ROUND(AVG(recency_days), 0)                                 AS avg_recency_days
FROM segments
GROUP BY 1
ORDER BY revenue DESC;

-- Q10. Monthly cohort retention: of customers whose first order was in month X,
--      what % ordered again within the next 1, 3 and 6 months?
WITH first_order AS (
    SELECT customer_unique_id,
           MIN(DATE_TRUNC('month', order_purchase_timestamp)) AS cohort_month
    FROM v_delivered_orders
    GROUP BY 1
), activity AS (
    SELECT f.customer_unique_id,
           f.cohort_month,
           (EXTRACT(YEAR FROM d.order_purchase_timestamp) - EXTRACT(YEAR FROM f.cohort_month)) * 12
         + (EXTRACT(MONTH FROM d.order_purchase_timestamp) - EXTRACT(MONTH FROM f.cohort_month))
               AS month_number
    FROM first_order f
    JOIN v_delivered_orders d USING (customer_unique_id)
)
SELECT cohort_month::date,
       COUNT(DISTINCT customer_unique_id)                                                 AS cohort_size,
       ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE month_number = 1)
             / COUNT(DISTINCT customer_unique_id), 2)                                     AS m1_pct,
       ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE month_number BETWEEN 1 AND 3)
             / COUNT(DISTINCT customer_unique_id), 2)                                     AS within_3m_pct,
       ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE month_number BETWEEN 1 AND 6)
             / COUNT(DISTINCT customer_unique_id), 2)                                     AS within_6m_pct
FROM activity
WHERE cohort_month < '2018-03-01'   -- later cohorts don't have 6 months of history yet
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------
-- SECTION D: Delivery & customer satisfaction
-- ---------------------------------------------------------------------

-- Q11. Delivery performance: actual delivery time and late-delivery rate
SELECT ROUND(AVG(EXTRACT(EPOCH FROM order_delivered_customer_date - order_purchase_timestamp) / 86400), 1)
           AS avg_delivery_days,
       ROUND(AVG(EXTRACT(EPOCH FROM order_estimated_delivery_date - order_purchase_timestamp) / 86400), 1)
           AS avg_promised_days,
       ROUND(100.0 * AVG(CASE WHEN order_delivered_customer_date::date > order_estimated_delivery_date::date
                              THEN 1 ELSE 0 END), 1)
           AS late_pct
FROM v_delivered_orders
WHERE order_delivered_customer_date IS NOT NULL;

-- Q12. Does late delivery hurt review scores?
WITH order_delivery AS (
    SELECT d.order_id,
           CASE
               WHEN d.order_delivered_customer_date::date <= d.order_estimated_delivery_date::date
                    THEN '1. On time'
               WHEN d.order_delivered_customer_date::date - d.order_estimated_delivery_date::date <= 7
                    THEN '2. Late 1-7 days'
               ELSE '3. Late 8+ days'
           END AS delivery_status
    FROM v_delivered_orders d
    WHERE d.order_delivered_customer_date IS NOT NULL
)
SELECT od.delivery_status,
       COUNT(*)                                                  AS reviews,
       ROUND(AVG(r.review_score), 2)                             AS avg_score,
       ROUND(100.0 * AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END), 1) AS pct_bad_reviews
FROM order_delivery od
JOIN order_reviews r ON r.order_id = od.order_id
GROUP BY 1
ORDER BY 1;

-- Q13. States with the slowest delivery (min. 500 orders)
SELECT customer_state,
       COUNT(*) AS orders,
       ROUND(AVG(EXTRACT(EPOCH FROM order_delivered_customer_date - order_purchase_timestamp) / 86400), 1)
           AS avg_delivery_days,
       ROUND(100.0 * AVG(CASE WHEN order_delivered_customer_date::date > order_estimated_delivery_date::date
                              THEN 1 ELSE 0 END), 1) AS late_pct
FROM v_delivered_orders
WHERE order_delivered_customer_date IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 500
ORDER BY avg_delivery_days DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- SECTION E: Payments & sellers
-- ---------------------------------------------------------------------

-- Q14. Payment methods and installment usage
SELECT payment_type,
       COUNT(DISTINCT p.order_id)                                       AS orders,
       ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 1) AS value_share_pct,
       ROUND(AVG(payment_installments), 1)                              AS avg_installments
FROM order_payments p
JOIN v_delivered_orders d ON d.order_id = p.order_id
GROUP BY 1
ORDER BY orders DESC;

-- Q15. Seller concentration: what share of revenue do the top 10% of sellers bring?
WITH seller_rev AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN v_delivered_orders d ON d.order_id = oi.order_id
    GROUP BY 1
), bucketed AS (
    SELECT *, NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_rev
)
SELECT decile,
       COUNT(*)                                                     AS sellers,
       ROUND(SUM(revenue), 0)                                       AS revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)   AS revenue_share_pct
FROM bucketed
GROUP BY decile
ORDER BY decile;
