/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 

     BEGIN TRY

       SET @batch_start_time = GETDATE();

        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading Olist E-Commerce Tables';
		PRINT '------------------------------------------------';

-- ==============================================================================================================================================================================================================================================================

       -- LODING silver.product_category_translation 
       SET @start_time = GETDATE();
       PRINT '>> Truncating Table: silver.product_category_translation';
       TRUNCATE TABLE silver.product_category_translation;
       PRINT '>> Inserting Data Into: silver.product_category_translation';

       INSERT INTO silver.product_category_translation(
            
            product_category_name_pt,
            product_category_name_eng
              
       )
       SELECT 
            TRIM(REPLACE(product_category_name , '"','')) AS product_category_name_pt,
            TRIM(REPLACE(product_category_name_english, '"' , '')) AS product_category_name_eng
       FROM bronze.category_translation; 

       SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

--======================================================================================================================================================================================================================================================
      -- LOADING silver.customers
      SET @start_time = GETDATE();

      PRINT '>> Truncating Table: silver.customers';
      TRUNCATE TABLE silver.customers;
      PRINT '>> Inserting Data Into: silver.customers';

      INSERT INTO silver.customers (

          customer_id ,
	      customer_unique_id ,
	      customer_zip_code_prefix ,
	      customer_city ,
	      customer_state 

      )

      SELECT  
          TRIM(REPLACE(customer_id , '"' , '')) AS customer_id,  -- Strip literal quotes left by Bronze's raw load
          TRIM(REPLACE(customer_unique_id , '"' , '')) AS customer_unique_id,
          TRIM(REPLACE(customer_zip_code_prefix , '"' , '')) AS customer_zip_code_prefix,
          TRIM(REPLACE(customer_city , '"' , '')) AS customer_city,
          TRIM(REPLACE(customer_state , '"' , '')) AS customer_state
     FROM bronze.customers

      
      SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

-- ==================================================================================================================================================================================================================================================
     
      -- LOADING silver.geolocation
      SET @start_time = GETDATE();

      PRINT '>> Truncating Table: silver.geolocation';
      TRUNCATE TABLE silver.geolocation;
      PRINT '>> Inserting Data Into: silver.geolocation';

      INSERT INTO silver.geolocation (
      
          geolocation_zip_code_prefix,
          geolocation_lat,
          geolocation_lng        
        
      )
      SELECT
          TRIM(REPLACE(geolocation_zip_code_prefix , '"' , '')) AS geolocation_zip_code_prefix,
          AVG(geolocation_lat) AS geolocation_lat,
          AVG(geolocation_lng) AS geolocation_lng   
      FROM bronze.geolocation

      WHERE geolocation_lat BETWEEN -35 AND 6
          AND geolocation_lng BETWEEN -75 AND -33
      GROUP BY TRIM(REPLACE(geolocation_zip_code_prefix, '"', ''));



      SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

--  =========================================================================================================================================================================================================================
      

      SET @start_time = GETDATE();


      PRINT '>> Truncating Table: silver.order_items';
      TRUNCATE TABLE silver.order_items;
      PRINT '>> Inserting Data Into: silver.order_items';

      INSERT INTO silver.order_items (
           
           order_id, 
           order_item_id,
           product_id,
           seller_id,
           shipping_limit_date,
           price,
           freight_value
      
      )

      SELECT
           TRIM(REPLACE(order_id , '"' ,'')) AS order_id,
           order_item_id,
           TRIM(REPLACE(product_id , '"' ,'')) As product_id,
           TRIM(REPLACE(seller_id , '"' ,'')) as seller_id,
           shipping_limit_date,
           price,
           freight_value
      FROM bronze.order_items


      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND , @start_time , @end_time) AS NVARCHAR) + 'Seconds';
      PRINT '----------------------'

-- =================================================================================================================================================================================================================================
    
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table silver.order_payments';
    TRUNCATE TABLE silver.order_payments;
    PRINT '>> Inserting data into : silver.order_payments';

    INSERT INTO silver.order_payments (
    
       order_id ,
       payment_sequential,
       payment_type,
       payment_installments ,
       payment_value 
    
    )

    SELECT 
       TRIM(REPLACE(order_id ,'"' ,'')) AS order_id,
       payment_sequential,
       payment_type,
       payment_installments,
       payment_value
    FROM  bronze.order_payments
    WHERE payment_type <> 'not_defined';

    
    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

-- ======================================================================================================================================================================================================
    

    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.order_reviews';
    TRUNCATE TABLE silver.order_reviews;
    PRINT '>> Inserting Data Into: silver.order_reviews';

    INSERT INTO silver.order_reviews (

        review_id,
        order_id,
        review_score,
        review_creation_date,
        review_answer_timestamp
    )
    SELECT
        TRIM(REPLACE(review_id, '"', '')) AS review_id,
        TRIM(REPLACE(order_id, '"', '')) AS order_id,
        review_score,
        review_creation_date,
        review_answer_timestamp
    FROM bronze.order_reviews;


    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' Seconds'
    PRINT '>> -------------';


    -- ===================================================================================================================================================================================================================

    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.orders';
    TRUNCATE TABLE silver.orders;
    PRINT '>> Inserting Data Into: silver.orders';

    INSERT INTO silver.orders (
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    )

    SELECT
        TRIM(REPLACE(order_id, '"', '')) AS order_id,
        TRIM(REPLACE(customer_id, '"', '')) AS customer_id,
        TRIM(REPLACE(order_status, '"', '')) AS order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    FROM bronze.orders;

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';


-- ========================================================================================================================================================================================================

    
    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.products';
    TRUNCATE TABLE silver.products;
    PRINT '>> Inserting Data Into: silver.products';

    INSERT INTO silver.products (
        product_id,
        product_category_name_pt,
        product_category_name_eng
    )

    SELECT
        TRIM(REPLACE(p.product_id, '"', '')) AS product_id,
        ISNULL(NULLIF(TRIM(REPLACE(p.product_category_name, '"', '')), ''), 'uncategorized') AS product_category_name_pt,
        COALESCE(t.product_category_name_eng, NULLIF(TRIM(REPLACE(p.product_category_name, '"', '')), ''), 'uncategorized') AS product_category_name_eng
    FROM bronze.products p
    LEFT JOIN silver.product_category_translation t
        ON TRIM(REPLACE(p.product_category_name, '"', '')) = t.product_category_name_pt;


    SET @end_time = GETDATE();

    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';


-- =======================================================================================================================================================================

    SET @start_time = GETDATE();

    PRINT '>> Truncating Table: silver.sellers';
    TRUNCATE TABLE silver.sellers;
    PRINT '>> Inserting Data Into: silver.sellers';

    INSERT INTO silver.sellers (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
    SELECT
        TRIM(REPLACE(seller_id, '"', '')) AS seller_id,
        TRIM(REPLACE(seller_zip_code_prefix, '"', '')) AS seller_zip_code_prefix,
        TRIM(REPLACE(seller_city, '"', '')) AS seller_city,
        TRIM(REPLACE(seller_state, '"', '')) AS seller_state
    FROM bronze.sellers;

    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

-- ==================================================================================================================================================================================================


END TRY

BEGIN CATCH 

    PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='

    THROW;  

END CATCH

END
