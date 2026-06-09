/*
	# ============================================================================ #
		Model: Staging API Customer Info
	# ============================================================================ #

    Script Purpose: This script loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Removal of prefix and whitespaces for customer id (id).
    - Initial capitilization and whitespace removal for first name (first_name), last name (last_name).
    - Mapping gender statements with long format names.
    - Replacement of invalid birthdate with NULL.
    - Initial capitalization for city, state and country

    Run Command: dbt run --select stg_djapi__customer
    Test Command: dbt test --select stg_djapi__customer

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_djapi__customer' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_api', 'djapi_customer') }}
),
cleaned AS(
    SELECT
        CAST(TRIM(REPLACE(id,'dummy-','')) AS INT) AS id -- Clear prefix.
        ,CASE 
            WHEN first_name IS NULL THEN 'n/a' -- Replace NULL value with string 'n/a'.
            ELSE UPPER(LEFT(TRIM(first_name), 1)) + LOWER(SUBSTRING(TRIM(first_name), 2, LEN(first_name))) -- Set first character as uppercase and rest of it lowercase.
        END AS first_name
        ,CASE 
            WHEN last_name IS NULL THEN 'n/a' -- Replace NULL value with string 'n/a'.
            ELSE UPPER(LEFT(TRIM(last_name), 1)) + LOWER(SUBSTRING(TRIM(last_name), 2, LEN(last_name))) -- Set first character as uppercase and rest of it lowercase.
        END AS last_name
        ,CASE 
            WHEN (gender IS NULL OR gender = '') THEN 'n/a' -- Replace NULL value or empty string with string 'n/a'.
            WHEN UPPER(TRIM(gender)) IN ('M','MALE') THEN 'Male'
            WHEN UPPER(TRIM(gender)) IN ('F','FEMALE') THEN 'Female'
            ELSE 'n/a'
        END AS gender
        ,CASE								-- Set future and out-of-range birthday dates to NULL.
            WHEN (birthdate < '1900-01-01' OR (birthdate > DATEADD( YEAR, -18, GETDATE() ))) THEN NULL
            ELSE birthdate
        END AS birthdate
        ,[dbo].[FN_InitCap](TRIM(city)) AS city -- Set first character of each word uppercase.
        ,[dbo].[FN_InitCap](TRIM([state])) AS [state] -- Set first character of each word uppercase.
        ,UPPER(TRIM(state_code)) AS state_code -- Set first character of each word uppercase.
        ,[dbo].[FN_InitCap](TRIM(country)) AS country -- Set first character of each word uppercase.
    FROM
        source
)

SELECT * FROM cleaned