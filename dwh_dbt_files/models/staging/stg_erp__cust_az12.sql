/*
	# ============================================================================ #
		Model: Staging ERP Customer Info
	# ============================================================================ #

    Script Purpose: This script performs transformation and loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Extraction of prefix ('NAS') from customer id.
    - Replace NULL values on customer birthdate (bdate) if it is earlier than 1900-01-01 or is below 18 years old.
    - Mapping of gender values. (M -> Male, F -> Female, NULL -> n/a) 
    
    Run Command: dbt run --select stg_erp__cust_az12
    Test Command: dbt test --select stg_erp__cust_az12

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_erp__cust_az12' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_erp', 'erp_cust_az12') }}
),
cleaned AS (
    SELECT
        CASE								-- Remove 'NAS' prefix
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) 
            ELSE cid
        END AS cid 
        ,CASE								-- Set future and out-of-range birthday dates to NULL.
            WHEN (bdate < '1900-01-01' OR (bdate > DATEADD( YEAR, -18, GETDATE() ))) THEN NULL
            ELSE bdate
        END AS bdate
        ,CASE UPPER(TRIM(COALESCE(gen,'')))	-- Replace gender values
            WHEN '' THEN 'n/a'
            WHEN 'F' THEN 'Female'
            WHEN 'M' THEN 'Male'
            ELSE gen
        END AS gen
        ,GETDATE() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned