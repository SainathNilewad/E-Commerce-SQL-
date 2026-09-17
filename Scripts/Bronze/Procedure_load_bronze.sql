CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    BEGIN TRY

    DECLARE @start_time DATETIME, @end_time DATETIME;
        PRINT ' =====================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '----------------------------------------------------';
        PRINT ' Loading olist E-commerce Files';

        SET @start_time = GETDATE();
        TRUNCATE TABLE bronze.category_translation

        BULK INSERT bronze.category_translation
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\product_category_name_translation.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0d0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT 'LOAD DURATION: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';


        TRUNCATE TABLE bronze.customers

        BULK INSERT bronze.customers
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_customers_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.geolocation

        BULK INSERT bronze.geolocation
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_geolocation_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.order_items

        BULK INSERT bronze.order_items
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_order_items_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.order_payments

        BULK INSERT bronze.order_payments
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_order_payments_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.order_reviews

        BULK INSERT bronze.order_reviews
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_order_reviews_dataset.csv'
        WITH (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0d0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.orders

        BULK INSERT bronze.orders
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_orders_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.products

        BULK INSERT bronze.products
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_products_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );


        TRUNCATE TABLE bronze.sellers

        BULK INSERT bronze.sellers
        FROM 'D:\Project\E-Commerce SQL ETL\RAW DATA\olist_sellers_dataset.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

    END TRY
    BEGIN CATCH
        PRINT '===========================================================================';
        PRINT 'ERROR OCCURRED: ' + ERROR_MESSAGE();
        PRINT '===========================================================================';
    END CATCH
END
