/* 

===========================================================================================================================================================================================================================================================================================

Create Database and Schemas

==========================================================================================================================================================================================================================================================================================

Script Purpose:
     This script creates a new database named 'DataWarehouse' after checking if it already exists.
     If the database exits, it is dropped and recreated. Additionally, the scipt sets up three schemas
     within the database: 'bronze' , 'silver' , 'gold'.


WARNING:
    Running this scipt will drop the entire 'DataWarehouse' database if it exits.
    All data in the database will be permanently deleted. Proceed with caution
    and ensure you have proper backups running this script.

*/

Use master;
GO


-- Drop and recreate the 'DataWarehouse' database

IF EXISTS (SELECT 1 FROM sys.databases WHERE name= 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO


-- Create the 'DataWarehouse' database
Create Database DataWarehouse;
GO

Use DataWarehouse;
GO


-- Create Schemas
CREATE SCHEMA bronze;
GO


CREATE SCHEMA silver;
GO 


CREATE SCHEMA gold;
GO
