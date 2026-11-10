-- =====================================================================
-- Olist E-Commerce SQL Analysis
-- 03 - Data quality checks
-- Always check the data before analysing it.
-- =====================================================================

-- 3.1 Order status distribution
--     Only 'delivered' orders are used for revenue analysis later.
SELECT order_status,
       COUNT(*)                                            AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3.2 Date range covered by the data
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- 3.3 Orders per month: the first and last months are almost empty
--     and are excluded from trend analysis.
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
       COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

-- 3.4 Missing values in key columns
SELECT
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)                  AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)      AS missing_delivered,
    COUNT(*) FILTER (WHERE order_status = 'delivered'
                       AND order_delivered_customer_date IS NULL)      AS delivered_but_no_date
FROM orders;

SELECT COUNT(*) FILTER (WHERE product_category_name IS NULL) AS products_without_category,
       COUNT(*)                                              AS total_products
FROM products;

-- 3.5 Duplicate check: customer_id is per order, customer_unique_id is the real person
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- 3.6 Duplicate review_ids
SELECT COUNT(*) AS review_rows, COUNT(DISTINCT review_id) AS distinct_review_ids
FROM order_reviews;

-- 3.7 Does payment total match item price + freight? (sanity check)
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM order_items GROUP BY order_id
), pay_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM order_payments GROUP BY order_id
)
SELECT COUNT(*)                                                    AS orders_compared,
       COUNT(*) FILTER (WHERE ABS(items_total - paid_total) > 1)   AS mismatch_over_1_brl
FROM item_totals i
JOIN pay_totals p USING (order_id);
