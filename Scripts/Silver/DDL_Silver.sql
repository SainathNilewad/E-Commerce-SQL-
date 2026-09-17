/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'silver' Tables
===============================================================================
*/


IF OBJECT_ID('silver.product_category_translation' , 'U') IS NOT NULL
DROP TABLE silver.product_category_translation;

GO

CREATE TABLE silver.product_category_translation(
      
	product_category_name_pt NVARCHAR(100),
	product_category_name_eng NVARCHAR(100)

);

GO

IF OBJECT_ID('silver.customers' , 'U') IS NOT NULL
DROP TABLE silver.customers;

GO

CREATE TABLE silver.customers(
	
	customer_id VARCHAR(50),
	customer_unique_id VARCHAR(50),
	customer_zip_code_prefix VARCHAR(50),
	customer_city NVARCHAR(100),
	customer_state VARCHAR(100)
	
);
 GO

 IF OBJECT_ID('silver.geolocation' , 'U') IS NOT NULL
 DROP TABLE silver.geolocation

 GO  
   
CREATE TABLE silver.geolocation (
    
	geolocation_zip_code_prefix VARCHAR(50),
	geolocation_lat DECIMAL(18,8),
	geolocation_lng DECIMAL(18,8)

);

GO

IF OBJECT_ID('silver.order_items' , 'U') IS NOT NULL
    DROP TABLE silver.order_items
GO
  
CREATE TABLE silver.order_items (

	order_id VARCHAR(50),
	order_item_id VARCHAR(50),
	product_id VARCHAR(50),
	seller_id VARCHAR(50),
	shipping_limit_date DATETIME,
	price DECIMAL(18,2),
	freight_value DECIMAL(18,2)

);
GO

IF OBJECT_ID('silver.order_payments' , 'U') IS NOT NULL 
   DROP TABLE silver.order_payments

GO  
  
CREATE TABLE silver.order_payments (
		
   order_id VARCHAR(50),
   payment_sequential INT,
   payment_type VARCHAR(50),
   payment_installments INT,
   payment_value DECIMAl(18,4)

);

GO

IF OBJECT_ID('silver.order_reviews' , 'U') IS NOT NULL 
   DROP TABLE silver.order_reviews
  
GO
  
CREATE TABLE silver.order_reviews (
   
   review_id VARCHAR(50),
   order_id VARCHAR(50),
   review_score INT ,
   review_creation_date DATETIME,
   review_answer_timestamp DATETIME

);

GO

IF OBJECT_ID('silver.orders' , 'U') IS NOT NULL
   DROP TABLE silver.orders

GO  
  
CREATE TABLE silver.orders(
    
		order_id VARCHAR(50),
		customer_id VARCHAR(50),
		order_status VARCHAR(50),
		order_purchase_timestamp DATETIME,
		order_approved_at DATETIME,
		order_delivered_carrier_date DATETIME,
		order_delivered_customer_date DATETIME,
		order_estimated_delivery_date DATETIME

);

GO

IF OBJECT_ID('silver.products' , 'U') IS NOT NULL
  DROP TABLE silver.products

GO
  
CREATE TABLE silver.products(
    product_id VARCHAR(50),
    product_category_name_pt NVARCHAR(100),
    product_category_name_eng NVARCHAR(100)

)
GO

IF OBJECT_ID('silver.sellers', 'U') IS NOT NULL 
    DROP TABLE silver.sellers
GO
  
CREATE TABLE silver.sellers(

    seller_id VARCHAR(50),
	seller_zip_code_prefix VARCHAR(50),
	seller_city NVARCHAR(32),
    seller_state NVARCHAR(32)
);

