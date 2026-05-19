/*
CREATE DATABASE AND SCHEMAS

Script Purpose: This script creates a data warehouse if not exists. It also creates three schemas: bronze, silver and gold.

WARNING:
- Ensure that you have the necessary permissions to create databases and schemas on the SQL Server instance.
- Running this script will create a new database named 'DataWarehouse' and three schemas within it. If there is an existing database with the same name, it will be dropped and recreated. Make sure that there is no existing database with the same name to avoid conflicts.
*/

USE master;
GO

-- Checks if there is a database named 'DataWarehouse' and drops it if it exists.
IF EXISTS (SELECT 1 FROM sys.databases WHERE NAME = 'DataWarehouse') BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END
GO

-- Creates a new database named 'DataWarehouse'.
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Created schemas for different layers.
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO