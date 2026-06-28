/*
	# ============================================================================ #
		Model: Staging ERP Customer Location Info
	# ============================================================================ #

    Script Purpose: This script performs transformation and loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Extraction of special characters from customer id.
    - Mapping country abbreviations with long format names.
    
    Run Command: dbt run --select stg_erp__loc_a101
    Test Command: dbt test --select stg_erp__loc_a101

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_erp__loc_a101' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_erp', 'erp_loc_a101') }}
),
cleaned AS (
    SELECT
        REPLACE(cid,'-','') AS cid				-- Remove dash character from id.
        ,CASE TRIM(REPLACE(UPPER(COALESCE(cntry, '')), '\r', ''))	-- Normalize and handle missing or blank country codes.
            WHEN 'US' THEN 'United States'
            WHEN 'USA' THEN 'United States'
            WHEN 'DE' THEN 'Germany'
            WHEN 'AU' THEN 'Australia'
            WHEN 'AUS' THEN 'Australia'
            WHEN 'CA' THEN 'Canada'
            WHEN 'CAN' THEN 'Canada'
            WHEN 'FR' THEN 'France'
            WHEN 'UK' THEN 'United Kingdom'
            WHEN '' THEN 'n/a'
            ELSE TRIM(REPLACE(cntry, '\r', ''))
        END AS cntry
        ,CURRENT_TIMESTAMP() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned