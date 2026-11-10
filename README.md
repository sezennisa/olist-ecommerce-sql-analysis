# Brazilian E-Commerce Analysis with SQL (PostgreSQL)

An end-to-end SQL analysis of **~100,000 real orders** from Olist, the largest department store on Brazilian marketplaces (2016–2018).
The project covers database design, data loading, data quality checks and 15 business questions, answered with PostgreSQL.

**Dataset:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
**Tools:** PostgreSQL 18, pgAdmin 4

**Full report (in French):** [rapport.pdf](rapport.pdf)

---

## Key findings

| Area | Finding |
|---|---|
| **Growth** | Revenue grew **2.4×** year over year (Jan–Aug 2018 vs. 2017: R$ 8.45M vs. R$ 3.47M) while average order value stayed flat at ~R$ 160. Growth came from **more customers**, not bigger baskets. |
| **Seasonality** | Black Friday made **Nov 2017 the best month** of the period (+54% vs. October). Since early 2018, monthly revenue has plateaued at around R$ 1.0–1.1M. |
| **Retention** | **97% of customers ordered only once.** Fewer than 2.3% of any monthly cohort came back within 6 months. This is the biggest weakness in the business. |
| **Delivery → reviews** | On-time orders average **4.29★**. Orders 8+ days late average **1.70★**, and 79% of them get a 1–2★ review. Delivery speed is clearly linked to customer satisfaction. |
| **Delivery promise** | Orders arrive in 12.5 days on average, but the promised date is 23.6 days. Only 6.8% arrive late overall, yet northern and northeastern states (PA, MA, CE) wait 20+ days and see 11–18% late rates. |
| **Geography** | São Paulo (SP) generates **37%** of revenue. It also has the lowest freight cost (R$ 17 vs. R$ 24–30 elsewhere). |
| **Categories** | The top 10 categories make up 62% of revenue. Health & beauty, watches & gifts and bed/bath/table lead. |
| **Sellers** | The top 10% of sellers generate **67% of revenue**. |
| **Payments** | Credit cards cover 78% of payment value, with an average of 3.5 installments. Boleto (bank slip) covers 18%. |

### Recommendations
1. **Invest in retention.** With a ~3% repeat rate, even a small improvement (post-purchase emails, a second-order coupon) would have a large impact. The 20,600 "at risk, high-value" customers identified by RFM segmentation are the first group to target.
2. **Fix late deliveries in the North/Northeast.** Orders that arrive more than a week late get less than half the average rating of on-time orders. Regional carriers or a local warehouse could protect ratings.
3. **Protect key sellers.** Revenue depends heavily on ~300 sellers, so a seller-success program would reduce that risk.

---

## Project structure

| File | Contents |
|---|---|
| `01_create_tables.sql` | Schema: 8 tables with primary keys, foreign keys, a CHECK constraint and indexes |
| `02_load_data.sql` | Loads the Kaggle CSV files with `\copy` and verifies the row counts |
| `03_data_quality.sql` | Status distribution, date coverage, missing values, duplicates, payment reconciliation |
| `04_business_analysis.sql` | 15 business questions in 5 sections (sales, products, customers, delivery, payments/sellers) |

### Data model
```
customers ─┐
           └─< orders ─┬─< order_items >── products ── category_translation
                       │        └──────>── sellers
                       ├─< order_payments
                       └─< order_reviews
```

### SQL techniques used
- Multi-table `JOIN`s, `LEFT JOIN` for incomplete lookups
- CTEs (`WITH`) and a reusable **view** (`v_delivered_orders`)
- **Window functions:** `LAG`, `RANK`, `NTILE`, `SUM() OVER()`, running totals, a 3-month rolling average
- Conditional aggregation with `FILTER` and `CASE WHEN`
- Date handling: `DATE_TRUNC`, `EXTRACT`, intervals
- RFM customer segmentation and monthly cohort retention analysis
- Data quality checks before analysis

---

## Data quality notes
- 97% of orders have the status `delivered`. Only delivered orders are used for revenue analysis.
- Sep–Dec 2016 and Sep–Oct 2018 contain very few orders, so the analysis covers **Jan 2017 – Aug 2018**.
- `customer_id` is generated per order. `customer_unique_id` identifies the real person (99,441 IDs map to 96,096 people), so all customer metrics use `customer_unique_id`.
- `review_id` is not unique in the raw data, so the reviews table has no primary key.
- 610 products have no category. They appear as `unknown`.
- Two Portuguese category names were missing from the translation table and were added manually.

---

## How to run
1. Download the dataset from Kaggle and unzip it.
2. Create the database: `CREATE DATABASE olist;`
3. Run `01_create_tables.sql` (in the pgAdmin Query Tool or psql).
4. From the folder that contains the CSV files, run:
   `psql -U postgres -d olist -f 02_load_data.sql`
5. Open `03_data_quality.sql` and `04_business_analysis.sql` in the pgAdmin Query Tool and run the queries one at a time.
