/*
	# ============================================================================ #
		Model: Staging API Order Info
	# ============================================================================ #

    Script Purpose: This script loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Removal of prefix and whitespaces for order id, product id and customer id (id, prd_id, cust_id).
    - Normalization of quantity.
    - Derivation of total price (total_price) if it is not equal unit price x quantity.
        - If quantity > 0       >> total price = ABS(unit price) x ABS(quantity)
        - If quantity = 0       >> total price = unit price
        - If quantity IS NULL   >> total price = unit price
        - If quantity < 0       >> total price = price x ABS(quantity)
        * ABS -> Absolute function

    Run Command: dbt run --select stg_djapi__order
    Test Command: dbt test --select stg_djapi__order

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_djapi__order' on each run.
*/

WITH source AS (
    SELECT 
        * 
    FROM 
        {{ source('bronze_api', 'djapi_order') }}
    WHERE
        -- Get order records related with existing product and customer records.
        CAST(TRIM(REPLACE(prd_id,'dummy-','')) AS INT) IN (SELECT id FROM {{ ref('stg_djapi__product') }})
        AND CAST(TRIM(REPLACE(cust_id,'dummy-','')) AS INT) IN (SELECT id FROM {{ ref('stg_djapi__customer') }})
        -- Avoid records with wrong unit price.
        AND unit_price IS NOT NULL 
        AND unit_price > 0
),
cleaned AS(
    SELECT
	    CAST(TRIM(REPLACE(id,'dummy-','')) AS INT) AS id -- Clear prefix.
        ,CAST(TRIM(REPLACE(prd_id,'dummy-','')) AS INT) AS prd_id -- Clear prefix.
        ,CAST(TRIM(REPLACE(cust_id,'dummy-','')) AS INT) AS cust_id -- Clear prefix.
        ,unit_price 
        ,CASE	-- Normalize quantity
            WHEN quantity = 0 OR quantity IS NULL THEN 1
            WHEN quantity < 0 THEN ABS(quantity)
            ELSE quantity
        END AS quantity
        ,CASE	-- Derive total price with quantity * unit_price formula. (For inaccurate records)
            WHEN total_price IS NULL AND quantity IS NOT NULL AND unit_price IS NOT NULL THEN ABS(unit_price) * ABS(quantity)
            WHEN (total_price != unit_price * quantity) AND (quantity > 0) THEN unit_price * quantity
            WHEN (total_price != unit_price * quantity) AND ((quantity = 0) OR (quantity IS NULL)) THEN unit_price
            WHEN (total_price != unit_price * quantity) AND (quantity < 0) THEN unit_price * ABS(quantity)
            ELSE total_price
        END AS total_price
        ,GETDATE() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned