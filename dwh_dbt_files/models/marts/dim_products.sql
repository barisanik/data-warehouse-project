/*
	# ============================================================================ #
		Mart: Product Dimension
	# ============================================================================ #

    Script Purpose: Unified product dimension combining CRM CSV and DummyJSON API sources.

    Sources:
    - stg_crm__prd_info
    - stg_erp__px_cat_g1v2
    - stg_djapi__product
    
    Run Command: dbt run --select dim_products
    Test Command: dbt test --select dim_products

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'gold.dim_products' on each run.
*/

SELECT
    {{ dbt_utils.generate_surrogate_key(['product_id', 'data_source']) }} AS product_key -- Unique hash based surrogate key
    ,CASE
        WHEN data_source = 'csv' THEN CONCAT('CSV-', a.product_id)
        WHEN data_source = 'api' THEN CONCAT('API-', a.product_id)
        ELSE 'Unknown'
    END AS product_id
    ,product_number
    ,product_name
    ,category_id
    ,CASE
        WHEN category IS NULL THEN 'N/A'
        ELSE category
    END AS category
    ,CASE
        WHEN subcategory IS NULL THEN 'N/A'
        ELSE subcategory
    END AS subcategory
    ,CASE
        WHEN maintenance IS NULL THEN 'n/a'
        ELSE maintenance
    END AS maintenance
    ,CASE
        WHEN cost IS NULL THEN 0
        ELSE cost
    END AS cost
    ,CASE
        WHEN product_line IS NULL THEN 'Other Sales'
        ELSE product_line
    END AS product_line
    ,start_date
    ,data_source
FROM(
    SELECT
        -- Product identity
        CAST(cp.prd_id AS STRING) AS product_id
        ,cp.prd_key AS product_number
        ,cp.prd_nm AS product_name
        -- Product Category
        ,cp.cat_id AS category_id
        ,prc.cat AS category
        ,prc.subcat AS subcategory
        ,prc.maintenance
        -- Production Details
        ,cp.prd_cost AS cost
        ,cp.prd_line AS product_line
        ,cp.prd_start_dt AS start_date
        ,'csv' AS data_source
    FROM
        {{ ref('stg_crm__prd_info') }} cp
        LEFT JOIN {{ ref('stg_erp__px_cat_g1v2') }} prc ON cp.cat_id = prc.id
    WHERE
        cp.prd_end_dt IS NULL -- Keep only last records with avoiding historical records.

    UNION ALL

    SELECT
        CAST(dp.id AS STRING) AS product_id
        ,dp.pkey AS product_number
        ,dp.title AS product_name
        ,LEFT(dp.pkey,3) AS category_id
        ,dp.category AS category
        ,NULL AS subcategory
        ,NULL AS maintenance
        ,NULL AS cost
        ,NULL AS product_line
        ,EXTRACT(DATE FROM TIMESTAMP(dp.createdAt)) AS start_date
        ,'api' AS data_source
    FROM
        {{ ref('stg_djapi__product') }} dp
) a