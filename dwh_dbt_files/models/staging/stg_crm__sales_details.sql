/*
	# ============================================================================ #
		Model: Staging CRM Sales Details
	# ============================================================================ #

    Script Purpose: This script performs transformation and loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Nullification of invalid sale date (sls_order_dt), shipping date (sls_ship_dt) and due date (sls_due_dt).
    - Validation of total sale (sls_sales) amount.
        - Formula: sls_sales = sls_quantity * sls_price
    - Absoluted sale quantity (sls_quantity).
    - Derived sale unit price (sls_price).
        - Formula: sls_price = sls_sales / sls_quantity
    
    Run Command: dbt run --select stg_crm__sales_details
    Test Command: dbt test --select stg_crm__sales_details

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_crm__sales_details' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_crm', 'crm_sales_details') }}
),
cleaned AS (
    SELECT
        sls_ord_num
        ,sls_prd_key
        ,sls_cust_id
        ,CASE	-- Validated dates to prevent out of range or future date inserts.
            WHEN sls_order_dt IS NULL OR sls_order_dt <= 19000000 OR CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) > CAST(GETDATE() AS DATE) THEN NULL
            ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
        END AS sls_order_dt
        ,CASE
            WHEN sls_ship_dt IS NULL OR sls_ship_dt <= 19000000 THEN NULL
            ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
        END AS sls_ship_dt
        ,CASE
            WHEN sls_due_dt IS NULL OR sls_due_dt <= 19000000 THEN NULL
            ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
        END AS sls_due_dt
        ,CASE	-- Derived sales amount with (unit price x quantity) formula where the original value is NULL or less than or equal to zero.
            WHEN ((sls_sales IS NULL OR sls_sales <= 0) AND (sls_price IS NOT NULL)) THEN ABS(ISNULL(sls_quantity,1)) * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales
        ,ABS(ISNULL(sls_quantity,1)) AS sls_quantity -- Avoided zero, negative and null quantity value.
        ,CASE	-- Derived price value with (total sales price / quantity) formula where the original value is NULL, zero, or negative.
            WHEN ((sls_price IS NULL OR sls_price = 0) AND (sls_quantity IS NOT NULL AND ABS(sls_quantity) > 0) AND (sls_sales IS NOT NULL)) THEN CAST(CAST(sls_sales AS DECIMAL(10,2)) / ABS(sls_quantity) AS DECIMAL(10,2))
            WHEN sls_price < 0 THEN ABS(sls_price) -- Converted negative value to positive with absolute function.
            ELSE sls_price
        END AS sls_price
        ,GETDATE() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned