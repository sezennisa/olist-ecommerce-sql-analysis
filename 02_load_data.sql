-- =====================================================================
-- Olist E-Commerce SQL Analysis
-- 02 - Load the Kaggle CSV files
--
-- Run from the terminal, inside the folder that contains the CSV files:
--   psql -U postgres -d olist -f /path/to/02_load_data.sql
-- (\copy is a psql command, so it reads files from YOUR computer.)
-- Parent tables are loaded first so foreign keys are satisfied.
-- =====================================================================

\copy customers            FROM 'olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true)
\copy sellers              FROM 'olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true)
\copy category_translation FROM 'product_category_name_translation.csv'  WITH (FORMAT csv, HEADER true)
\copy products             FROM 'olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true)
\copy orders               FROM 'olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true)
\copy order_items          FROM 'olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true)
\copy order_payments       FROM 'olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true)
\copy order_reviews        FROM 'olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true)

-- Two categories exist in products but are missing from the translation file
INSERT INTO category_translation VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers')
ON CONFLICT DO NOTHING;

-- Row counts to confirm the load
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'sellers',        COUNT(*) FROM sellers
UNION ALL SELECT 'products',       COUNT(*) FROM products
UNION ALL SELECT 'orders',         COUNT(*) FROM orders
UNION ALL SELECT 'order_items',    COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*) FROM order_reviews;
