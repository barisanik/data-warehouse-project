USE [DataWarehouse]
GO

/****** Object:  UserDefinedFunction [dbo].[FN_InitCap]    Script Date: 5/31/2026 12:12:42 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[FN_InitCap](@input NVARCHAR(1000))
RETURNS NVARCHAR(1000) AS BEGIN
    -- FN: Capitalizes first letter of every word of input except @exceptions.
    -- Example Usage: SELECT [dbo].[FN_InitCap]('Lorem ipsum dolor sit amet.')
    DECLARE @result    NVARCHAR(1000) = ''
    DECLARE @word      NVARCHAR(1000) = ''
    DECLARE @char      NCHAR(1)
    DECLARE @i         INT = 1
    DECLARE @isFirstWord   BIT = 1 

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

    RETURN RTRIM(@result)
END
GO


