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
casted AS (
    SELECT
        sls_ord_num
        ,sls_prd_key
        ,SAFE_CAST(sls_cust_id AS INT64)    AS sls_cust_id
        ,SAFE_CAST(sls_order_dt AS INT64)   AS sls_order_dt
        ,SAFE_CAST(sls_ship_dt  AS INT64)   AS sls_ship_dt
        ,SAFE_CAST(sls_due_dt   AS INT64)   AS sls_due_dt
        ,SAFE_CAST(sls_sales    AS NUMERIC) AS sls_sales
        ,SAFE_CAST(sls_quantity AS INT64)   AS sls_quantity
        ,SAFE_CAST(sls_price    AS NUMERIC) AS sls_price
    FROM
        source
),
cleaned AS (
    SELECT
        sls_ord_num
        ,sls_prd_key
        ,sls_cust_id
        ,CASE	-- Validated dates to prevent out of range or future date inserts.
            WHEN sls_order_dt IS NULL OR sls_order_dt <= 19000000 OR PARSE_DATE('%Y%m%d', CAST(sls_order_dt AS STRING)) > CURRENT_DATE() THEN NULL
            ELSE PARSE_DATE('%Y%m%d', CAST(sls_order_dt AS STRING))
        END AS sls_order_dt
        ,CASE
            WHEN sls_ship_dt IS NULL OR sls_ship_dt <= 19000000 OR PARSE_DATE('%Y%m%d', CAST(sls_ship_dt AS STRING)) > CURRENT_DATE() THEN NULL
            ELSE PARSE_DATE('%Y%m%d', CAST(sls_ship_dt AS STRING))
        END AS sls_ship_dt
        ,CASE
            WHEN sls_due_dt IS NULL OR sls_due_dt <= 19000000 OR PARSE_DATE('%Y%m%d', CAST(sls_due_dt AS STRING)) > CURRENT_DATE() THEN NULL
            ELSE PARSE_DATE('%Y%m%d', CAST(sls_due_dt AS STRING))
        END AS sls_due_dt
        ,CAST(CASE	-- Derived sales amount with (unit price x quantity) formula where the original value is NULL or less than or equal to zero.
            WHEN sls_sales IS NULL AND sls_quantity IS NOT NULL AND sls_price IS NOT NULL THEN ABS(sls_price) * ABS(sls_quantity)
            WHEN (sls_sales != sls_price * sls_quantity) AND (sls_quantity > 0) THEN ABS(sls_price) * sls_quantity
            WHEN (sls_sales != sls_price * sls_quantity) AND ((sls_quantity = 0) OR (sls_quantity IS NULL)) THEN ABS(sls_price)
            WHEN (sls_sales != sls_price * sls_quantity) AND (sls_quantity < 0) THEN ABS(sls_price) * ABS(sls_quantity)
            ELSE sls_sales
        END AS NUMERIC) AS sls_sales
        ,ABS(IFNULL(sls_quantity, 1)) AS sls_quantity -- Avoided zero, negative and null quantity value.
        ,CASE	-- Derived price value with (total sales price / quantity) formula where the original value is NULL, zero, or negative.
            WHEN ((sls_price IS NULL OR sls_price = 0) AND (sls_quantity IS NOT NULL AND ABS(sls_quantity) > 0) AND (sls_sales IS NOT NULL)) THEN CAST(sls_sales / ABS(sls_quantity) AS NUMERIC)
            WHEN sls_price < 0 THEN ABS(sls_price) -- Converted negative value to positive with absolute function.
            ELSE sls_price
        END AS sls_price
        ,CURRENT_TIMESTAMP() AS dwh_create_date
    FROM
        casted
)

SELECT * FROM cleaned