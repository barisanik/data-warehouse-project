/*
	# ============================================================================ #
		Model: Staging ERP Product Category Info
	# ============================================================================ #

    Script Purpose: This script loads data into the silver layer utilizing source tables of bronze layer.
    
    Run Command: dbt run --select stg_erp__px_cat_g1v2
    Test Command: dbt test --select stg_erp__px_cat_g1v2

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_erp__px_cat_g1v2' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_erp', 'erp_px_cat_g1v2') }}
),
cleaned AS(
    SELECT
        id
        ,cat
        ,subcat
        ,CASE UPPER(maintenance)
            WHEN 'YES' THEN 'Yes'
            WHEN 'Y' THEN 'Yes'
            WHEN 'NO' THEN 'No'
            WHEN 'N' THEN 'No'
            ELSE 'n/a'
        END AS maintenance
        ,GETDATE() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned