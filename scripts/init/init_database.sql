/*
CREATE DATABASE, SCHEMAS AND FUNCTION

Script Purpose: This script creates a data warehouse if not exists. It also creates three schemas: bronze, silver and gold.

WARNING:
- Ensure that you have the necessary permissions to create databases and schemas on the SQL Server instance.
- Running this script will create a new database named 'DataWarehouse' and three schemas within it. If there is an existing database with the same name, it will be dropped and recreated. Make sure that there is no existing database with the same name to avoid conflicts.
*/

USE master;
GO

-- Creates a new database named 'DataWarehouse'.
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DataWarehouse')
    CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Created schemas for different layers.
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

CREATE OR ALTER FUNCTION [dbo].[FN_InitCap](@input NVARCHAR(1000))
RETURNS NVARCHAR(1000) AS BEGIN
    -- FN: Capitalizes first letter of every word of input except @exceptions.
    -- Example Usage: SELECT [dbo].[FN_InitCap]('Lorem ipsum dolor sit amet.')
    DECLARE @result    NVARCHAR(1000) = ''
    DECLARE @word      NVARCHAR(1000) = ''
    DECLARE @char      NCHAR(1)
    DECLARE @i         INT = 1
    DECLARE @isFirstWord   BIT = 1 

    IF LOWER(@input) = 'n/a' BEGIN
        SET @result = 'n/a'
    END
    ELSE BEGIN
        DECLARE @exceptions TABLE (word NVARCHAR(50))
        INSERT INTO @exceptions VALUES ('and'),('or'),('at'),('the'),('a'),('an'),('in'),('of'),('to')

        SET @input = LOWER(@input) + NCHAR(0)

        WHILE @i <= LEN(@input)
        BEGIN
            SET @char = SUBSTRING(@input, @i, 1)

            IF @char = ' '
            BEGIN
                IF @isFirstWord = 0 AND EXISTS (SELECT 1 FROM @exceptions WHERE word = @word)   -- Checks if next word is member of exception list except first word of input. If it is leaves the word at it is.
                    SET @result = @result + @word + ' '
                ELSE                                                                            -- Set word's first character uppercase.
                    SET @result = @result + UPPER(LEFT(@word, 1)) + SUBSTRING(@word, 2, LEN(@word)) + ' '

                SET @word    = ''
                SET @isFirstWord = 0  
            END
            ELSE
                SET @word = @word + @char

            SET @i = @i + 1
        END
    END

    RETURN RTRIM(@result)
END
GO