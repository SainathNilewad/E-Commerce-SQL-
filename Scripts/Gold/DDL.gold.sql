/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Gold Layer: gold.dim_customers
-- =============================================================================
-- Grain: one row per customer_id.
-- Surrogate key (customer_key) generated for Gold, not exposing source ID.
-- LEFT JOIN to geolocation -- ~1% of customers have no matching zip in
-- geolocation, so lat/lng go NULL rather than a fabricated value.
-- has_geolocation flags rows with missing coordinates for visibility.
-- =============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY c.customer_id) AS customer_key,
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.geolocation_lat,
    g.geolocation_lng,
    CASE WHEN g.geolocation_lat IS NULL THEN 0 ELSE 1 END AS has_geolocation
FROM silver.customers c
LEFT JOIN silver.geolocation g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;
GO





-- =============================================================================
-- Gold Layer: gold.dim_products
-- =============================================================================
-- Grain: one row per product_id (32,951 rows, matches silver.products).
-- Surrogate key (product_key) generated for Gold.
-- category_name_eng is the primary display column for reporting;
-- category_name_pt kept alongside for traceability back to source.
-- =============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_key,
    p.product_id,
    p.product_category_name_pt,
    p.product_category_name_eng
FROM silver.products p;
GO



-- =============================================================================
-- Gold Layer: gold.dim_sellers
-- =============================================================================
-- Grain: one row per seller_id (3,095 rows, matches silver.sellers).
-- Surrogate key (seller_key) generated for Gold.
-- LEFT JOIN to geolocation, same pattern as dim_customers -- a small
-- percentage of sellers may have no matching zip in geolocation.
-- has_geolocation flags rows with missing coordinates.
-- =============================================================================

IF OBJECT_ID('gold.dim_sellers', 'V') IS NOT NULL
    DROP VIEW gold.dim_sellers;
GO

CREATE VIEW gold.dim_sellers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.seller_id) AS seller_key,
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.geolocation_lat,
    g.geolocation_lng,
    CASE WHEN g.geolocation_lat IS NULL THEN 0 ELSE 1 END AS has_geolocation
FROM silver.sellers s
LEFT JOIN silver.geolocation g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;
GO


-- =============================================================================
-- Gold Layer: gold.dim_date
-- =============================================================================
-- Built as a TABLE, not a view like the other Gold dimensions, because a
-- calendar is static reference data -- it never depends on Silver changing,
-- so there's no reason to recompute it on every query. This is also why a
-- table is required here: the recursive CTE below needs a MAXRECURSION
-- query hint, and SQL Server does not allow query hints inside a
-- CREATE VIEW definition.
--
-- Range: 2016-09-01 to 2018-12-31 (~852 days), based on the ACTUAL date
-- range found in the source data:
--   order_purchase_timestamp:       2016-09-04 to 2018-10-17
--   order_estimated_delivery_date:  2016-09-30 to 2018-11-12  <- widest
--   order_delivered_customer_date:  2016-10-11 to 2018-10-17
-- order_estimated_delivery_date is the widest-reaching date column in the
-- whole dataset, so it sets the true outer bound. A small buffer is added
-- on both ends rather than padding out to extra, unused years.
-- =============================================================================

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key      INT PRIMARY KEY,   -- date as an integer, e.g. 20180315, for fast joins
    calendar_date DATE,              -- the actual date value
    year          INT,               -- e.g. 2018
    month         INT,               -- 1-12
    month_name    VARCHAR(20),       -- e.g. 'March'
    day           INT,               -- 1-31
    day_name      VARCHAR(20),       -- e.g. 'Thursday'
    day_of_week   INT,               -- 1=Sunday ... 7=Saturday (SQL Server default)
    quarter       INT,               -- 1-4
    is_weekend    BIT                -- 1 if Saturday/Sunday, else 0
);
GO

-- Recursive CTE: generates one row per calendar day.
-- Starts at 2016-09-01, then repeatedly adds 1 day to the previous row's
-- date, stopping once it passes 2018-12-31. Think of it as a loop: take the
-- last date generated, add a day, check the limit, repeat -- until the
-- whole range is built one day at a time.
WITH DateRange AS (
    SELECT CAST('2016-09-01' AS DATE) AS calendar_date
    UNION ALL
    SELECT DATEADD(DAY, 1, calendar_date)
    FROM DateRange
    WHERE calendar_date < '2018-12-31'
)
INSERT INTO gold.dim_date (
    date_key, calendar_date, year, month, month_name,
    day, day_name, day_of_week, quarter, is_weekend
)
SELECT
    CONVERT(INT, FORMAT(calendar_date, 'yyyyMMdd')),        -- e.g. 20180315
    calendar_date,
    YEAR(calendar_date),
    MONTH(calendar_date),
    DATENAME(MONTH, calendar_date),
    DAY(calendar_date),
    DATENAME(WEEKDAY, calendar_date),
    DATEPART(WEEKDAY, calendar_date),
    DATEPART(QUARTER, calendar_date),
    CASE WHEN DATEPART(WEEKDAY, calendar_date) IN (1, 7) THEN 1 ELSE 0 END
FROM DateRange
-- SQL Server's recursive CTEs default to a max of 100 loops -- this range
-- needs ~852 loops (one per day), so the limit must be raised explicitly.
OPTION (MAXRECURSION 1000);
GO



-- =============================================================================
-- Gold Layer: gold.fact_order_items
-- =============================================================================
-- Grain: one row per order item (matches silver.order_items, 112,650 rows).
-- Joins in surrogate keys from every dimension, plus order-level attributes
-- (status, delivery dates) and item-level measures (price, freight).
-- Views, not a table -- same pattern as the other Gold dimensions, always
-- reflects current Silver data live.
-- =============================================================================

IF OBJECT_ID('gold.fact_order_items', 'V') IS NOT NULL
    DROP VIEW gold.fact_order_items;
GO

CREATE VIEW gold.fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    dd.date_key AS purchase_date_key,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.price,
    oi.freight_value,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS delivery_delay_days
FROM silver.order_items oi
INNER JOIN silver.orders o
    ON oi.order_id = o.order_id
LEFT JOIN gold.dim_customers c
    ON o.customer_id = c.customer_id
LEFT JOIN gold.dim_products p
    ON oi.product_id = p.product_id
LEFT JOIN gold.dim_sellers s
    ON oi.seller_id = s.seller_id
LEFT JOIN gold.dim_date dd
    ON CAST(o.order_purchase_timestamp AS DATE) = dd.calendar_date;
GO




-- =============================================================================
-- Gold Layer: gold.fact_payments
-- =============================================================================
-- Grain: one row per payment record (matches silver.order_payments,
-- 103,883 rows after excluding 'not_defined' in Silver). An order can have
-- multiple rows here if payment was split across methods (e.g. part
-- credit_card + part voucher).
-- =============================================================================

IF OBJECT_ID('gold.fact_payments', 'V') IS NOT NULL
    DROP VIEW gold.fact_payments;
GO

CREATE VIEW gold.fact_payments AS
SELECT
    op.order_id,
    op.payment_sequential,
    c.customer_key,
    dd.date_key AS purchase_date_key,
    o.order_status,
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM silver.order_payments op
INNER JOIN silver.orders o
    ON op.order_id = o.order_id
LEFT JOIN gold.dim_customers c
    ON o.customer_id = c.customer_id
LEFT JOIN gold.dim_date dd
    ON CAST(o.order_purchase_timestamp AS DATE) = dd.calendar_date;
GO




-- =============================================================================
-- Gold Layer: gold.fact_reviews
-- =============================================================================
-- Grain: one row per review (matches silver.order_reviews, 99,224 rows).
-- Composite (review_id, order_id) is the true source key -- review_id alone
-- can repeat across orders (Olist reuses one review submission across
-- multiple orders from the same purchase).
-- =============================================================================

IF OBJECT_ID('gold.fact_reviews', 'V') IS NOT NULL
    DROP VIEW gold.fact_reviews;
GO

CREATE VIEW gold.fact_reviews AS
SELECT
    r.review_id,
    r.order_id,
    c.customer_key,
    dd.date_key AS purchase_date_key,
    o.order_status,
    r.review_score,
    r.review_creation_date,
    r.review_answer_timestamp,
    DATEDIFF(DAY, r.review_creation_date, r.review_answer_timestamp) AS review_response_days
FROM silver.order_reviews r
INNER JOIN silver.orders o
    ON r.order_id = o.order_id
LEFT JOIN gold.dim_customers c
    ON o.customer_id = c.customer_id
LEFT JOIN gold.dim_date dd
    ON CAST(o.order_purchase_timestamp AS DATE) = dd.calendar_date;
GO
