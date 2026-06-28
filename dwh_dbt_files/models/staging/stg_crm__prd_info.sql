/*
	# ============================================================================ #
		Model: Staging CRM Product Info
	# ============================================================================ #

    Script Purpose: This script performs transformation and loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Seperation of category id and product key using prd_key column. First 5 character of prd_key is category id and rest of it is product key.
    - Applying InitCap formatting on product name (prd_nm).
    - Replacing NULL values with 0 on product cost (prd_cost).
    - Mapping on production line (prd_line) values.
    - Conversion of production start date (prd_start_dt) and production end date (prd_end_dt).
    - Calculation of production end date (prd_end_dt) using product key (prd_key) for historical records.
        - Example: There are 3 records of production for product X. It sets production end date as one day before of next production start date.
        - Warning: It will leave last production record's production end date as NULL.
    
    Run Command: dbt run --select stg_crm__prd_info
    Test Command: dbt test --select stg_crm__prd_info

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_crm__prd_info' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_crm', 'crm_prd_info') }}
),
cleaned AS (
    SELECT 
        prd_id
        ,REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id  -- Extracted the first 5 characters of product key as category code. Converted dash to underscore to join it with the ERP category table.
        ,SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS prd_key		-- Extracted the remaining part of the product key, to join with 'sls_prd_key' column of crm_sales_details.
        ,{{ fn_initcap('prd_nm') }}  AS prd_nm
        ,CAST(IFNULL(NULLIF(prd_cost, ''), '0') AS NUMERIC) AS prd_cost  -- Replaced NULL values with zero.
        ,CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line
        ,CAST(prd_start_dt AS DATE) AS prd_start_dt         -- Casted to DATE because the column does not contain time component.
        ,DATE_SUB(CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE), INTERVAL 1 DAY) AS prd_end_dt -- Calculated the production end date as one day prior to the next production start date. Casted to DATE for consistency.
        ,CURRENT_TIMESTAMP() AS dwh_create_date
    FROM 
        source
)

SELECT * FROM cleaned