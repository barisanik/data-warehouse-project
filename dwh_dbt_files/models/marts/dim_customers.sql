/*
	# ============================================================================ #
		Mart: Customer Dimension
	# ============================================================================ #

    Script Purpose: Unified customer dimension combining CRM CSV and DummyJSON API sources.

    Sources:
    - stg_crm__cust_info
    - stg_erp__cust_az12
    - stg_erp__loc_a101
    - stg_djapi__customer
    
    Run Command: dbt run --select dim_customers
    Test Command: dbt test --select dim_customers

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'gold.dim_customers' on each run.
*/

SELECT
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'data_source']) }} AS customer_key -- Unique hash based surrogate key
    ,CASE
        WHEN data_source = 'csv' THEN CONCAT('CSV-', a.customer_id)
        WHEN data_source = 'api' THEN CONCAT('API-', a.customer_id)
        ELSE 'Unknown'
    END AS customer_id
    ,customer_number
    ,first_name
    ,last_name
    ,country
    ,marital_status
    ,gender
    ,birthdate
    ,create_date
    ,data_source
FROM(
    SELECT
        CAST(ci.cst_id AS STRING) AS customer_id
        ,ci.cst_key AS customer_number
        ,ci.cst_firstname AS first_name
        ,ci.cst_lastname AS last_name
        ,el.cntry AS country
        ,ci.cst_marital_status AS marital_status
        ,CASE       -- If not null then CRM data source will be used as source.
            WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
            ELSE COALESCE(ca.gen,'n/a')
        END AS gender
        ,ca.bdate AS birthdate
        ,SAFE_CAST(ci.cst_create_date AS DATE) AS create_date
        ,'csv' AS data_source
    FROM
        {{ ref('stg_crm__cust_info') }} ci
        LEFT JOIN {{ ref('stg_erp__cust_az12') }} ca ON ci.cst_key = ca.cid
        LEFT JOIN {{ ref('stg_erp__loc_a101') }} el ON ci.cst_key = el.cid

    UNION ALL

    SELECT
        CAST(djc.id AS STRING) AS customer_id
        ,'n/a' AS customer_number
        ,djc.first_name AS first_name
        ,djc.last_name AS last_name
        ,djc.country AS country
        ,'n/a' AS marital_status
        ,djc.gender AS gender
        ,djc.birthdate AS birthdate
        ,SAFE_CAST(djc.dwh_create_date AS DATE) AS create_date
        ,'api' AS data_source
    FROM
        {{ ref('stg_djapi__customer') }} djc
) a