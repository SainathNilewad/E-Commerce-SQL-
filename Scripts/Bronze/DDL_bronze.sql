/*
===============================================================================
DDL Script: Create Bronze Tables - Olist E-Commerce Dataset
===============================================================================
Purpose:
    Creates the raw landing tables in the 'bronze' schema, dropping and
    recreating each one if it already exists. These tables hold data
    EXACTLY as it comes from the source CSV files -- no cleaning, no
    transformation, no type enforcement beyond what BULK INSERT requires.
    Bronze is intentionally left untouched after loading; all cleaning
    happens downstream in the Silver layer.

    Run this script once to (re)build the Bronze schema, before running
    the bronze.load_bronze stored procedure.
===============================================================================
*/

USE DataWarehouse;
GO

-- =============================================================================
-- bronze.customers
-- Source: olist_customers_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.customers', 'U') IS NOT NULL
    DROP TABLE bronze.customers;
GO

CREATE TABLE bronze.customers (
    customer_id                VARCHAR(50),
    customer_unique_id         VARCHAR(50),
    customer_zip_code_prefix   VARCHAR(50),
    customer_city               NVARCHAR(100),
    customer_state              VARCHAR(50)
);
GO

-- =============================================================================
-- bronze.geolocation
-- Source: olist_geolocation_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.geolocation', 'U') IS NOT NULL
    DROP TABLE bronze.geolocation;
GO

CREATE TABLE bronze.geolocation (
    geolocation_zip_code_prefix VARCHAR(50),
    geolocation_lat              DECIMAL(18,8),
    geolocation_lng              DECIMAL(18,8),
    geolocation_city             NVARCHAR(100),
    geolocation_state            VARCHAR(50)
);
GO

-- =============================================================================
-- bronze.order_items
-- Source: olist_order_items_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.order_items', 'U') IS NOT NULL
    DROP TABLE bronze.order_items;
GO

CREATE TABLE bronze.order_items (
    order_id             VARCHAR(50),
    order_item_id        INT,
    product_id           VARCHAR(50),
    seller_id            VARCHAR(50),
    shipping_limit_date  DATETIME,
    price                DECIMAL(18,2),
    freight_value        DECIMAL(18,2)
);
GO

-- =============================================================================
-- bronze.order_payments
-- Source: olist_order_payments_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.order_payments', 'U') IS NOT NULL
    DROP TABLE bronze.order_payments;
GO

CREATE TABLE bronze.order_payments (
    order_id              VARCHAR(50),
    payment_sequential    INT,
    payment_type          VARCHAR(50),
    payment_installments  INT,
    payment_value         DECIMAL(18,2)
);
GO

-- =============================================================================
-- bronze.order_reviews
-- Source: olist_order_reviews_dataset.csv
-- Note: this file contains embedded commas/newlines in review comment text --
-- handled at load time in bronze.load_bronze via FORMAT='CSV' + FIELDQUOTE.
-- =============================================================================
IF OBJECT_ID('bronze.order_reviews', 'U') IS NOT NULL
    DROP TABLE bronze.order_reviews;
GO

CREATE TABLE bronze.order_reviews (
    review_id                 VARCHAR(50),
    order_id                  VARCHAR(50),
    review_score              INT,
    review_comment_title      NVARCHAR(200),
    review_comment_message    NVARCHAR(MAX),
    review_creation_date      DATETIME,
    review_answer_timestamp   DATETIME
);
GO

-- =============================================================================
-- bronze.orders
-- Source: olist_orders_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.orders', 'U') IS NOT NULL
    DROP TABLE bronze.orders;
GO

CREATE TABLE bronze.orders (
    order_id                       VARCHAR(50),
    customer_id                    VARCHAR(50),
    order_status                   VARCHAR(50),
    order_purchase_timestamp       DATETIME,
    order_approved_at              DATETIME,
    order_delivered_carrier_date   DATETIME,
    order_delivered_customer_date  DATETIME,
    order_estimated_delivery_date  DATETIME
);
GO

-- =============================================================================
-- bronze.products
-- Source: olist_products_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.products', 'U') IS NOT NULL
    DROP TABLE bronze.products;
GO

CREATE TABLE bronze.products (
    product_id                  VARCHAR(50),
    product_category_name       NVARCHAR(100),
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);
GO

-- =============================================================================
-- bronze.sellers
-- Source: olist_sellers_dataset.csv
-- =============================================================================
IF OBJECT_ID('bronze.sellers', 'U') IS NOT NULL
    DROP TABLE bronze.sellers;
GO

CREATE TABLE bronze.sellers (
    seller_id               VARCHAR(50),
    seller_zip_code_prefix  VARCHAR(50),
    seller_city              NVARCHAR(100),
    seller_state              VARCHAR(50)
);
GO

-- =============================================================================
-- bronze.category_translation
-- Source: product_category_name_translation.csv
-- Portuguese -> English lookup for product_category_name.
-- =============================================================================
IF OBJECT_ID('bronze.category_translation', 'U') IS NOT NULL
    DROP TABLE bronze.category_translation;
GO

CREATE TABLE bronze.category_translation (
    product_category_name          NVARCHAR(100),
    product_category_name_english  NVARCHAR(100)
);
GO
