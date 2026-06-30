/*
	# ============================================================================ #
		Model: Staging API Product Info
	# ============================================================================ #

    Script Purpose: This script loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Removal of prefix and whitespaces for product id (id).
    - Initial capitilization, whitespace removal and null replacement for title and category.
    - Removal of suffix for product key (pkey).

    Run Command: dbt run --select stg_djapi__product
    Test Command: dbt test --select stg_djapi__product

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_djapi__product' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_api', 'djapi_product') }}
),
cleaned AS(
    SELECT
        CAST(TRIM(REPLACE(id,'dummy-','')) AS INT64) AS id -- Clear prefix.
        ,TRIM({{ fn_initcap("REPLACE(title, '\\r', '')") }}) AS title -- Set first character of each word uppercase.
        ,TRIM(INITCAP(REPLACE(IFNULL(REPLACE(category, '\r', ''),'n/a'),'-',' '))) AS category -- Set first character of each word uppercase.
        ,CASE 
            WHEN LENGTH(pkey) > 15 THEN SUBSTRING(UPPER(REPLACE(TRIM(pkey),'_','-')), 1, 15) -- Clear suffix
            ELSE UPPER(REPLACE(TRIM(pkey),'_','-')) 
        END AS pkey
        ,createdAt
        ,CURRENT_TIMESTAMP() AS dwh_create_date
    FROM
        source
    WHERE	
        title IS NOT NULL -- Avoid nameless products
)

SELECT * FROM cleaned