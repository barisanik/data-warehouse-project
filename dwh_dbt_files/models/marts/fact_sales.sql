/*
	# ============================================================================ #
		Mart: Fact Sale
	# ============================================================================ #

    Script Purpose: Unified order fact combining product and customer dimensions and silver CRM sales and API order sources.

    Sources:
    - dim_products
    - dim_customers
    - stg_crm__sales_details
    - stg_djapi__order
    
    Run Command: dbt run --select fact_sales
    Test Command: dbt test --select fact_sales

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'gold.fact_sales' on each run.
*/

SELECT
    {{ dbt_utils.generate_surrogate_key(['order_number', 'product_key', 'data_source']) }} AS order_key -- Unique hash based surrogate key
    ,CASE
        WHEN data_source = 'csv' THEN CONCAT('CSV-', CAST(a.order_number AS STRING))
        WHEN data_source = 'api' THEN CONCAT('API-', CAST(a.order_number AS STRING))
        ELSE 'Unknown'
    END AS order_number
    ,product_key
    ,customer_key
    ,CASE
        WHEN order_date > '1900-01-01' AND order_date < CURRENT_DATE() THEN CAST(order_date AS DATE)
        ELSE NULL
    END AS order_date
    ,CASE
        WHEN shipping_date > '1900-01-01' AND shipping_date < CURRENT_DATE() THEN CAST(shipping_date AS DATE)
        ELSE NULL
    END AS shipping_date
    ,CASE
        WHEN due_date > '1900-01-01' AND due_date < CURRENT_DATE() THEN CAST(due_date AS DATE)
        ELSE NULL
    END AS due_date
    ,total_sales_amount
    ,quantity
    ,unit_price
    ,data_source
FROM(
    SELECT
        REPLACE(sd.sls_ord_num,'SO','')         AS order_number
        ,pr.product_key                          AS product_key
        ,cu.customer_key                         AS customer_key
        ,sd.sls_order_dt                         AS order_date
        ,sd.sls_ship_dt                          AS shipping_date
        ,sd.sls_due_dt                           AS due_date
        ,sd.sls_sales                            AS total_sales_amount
        ,sd.sls_quantity                         AS quantity
        ,sd.sls_price                            AS unit_price
        ,cu.data_source                          AS data_source
    FROM
        {{ ref('stg_crm__sales_details') }} sd
        JOIN {{ ref('dim_products') }} pr ON sd.sls_prd_key = pr.product_number
        JOIN {{ ref('dim_customers') }} cu ON sd.sls_cust_id = REPLACE(cu.customer_id,'CSV-','') AND cu.data_source = 'csv'

    UNION ALL

    SELECT
        CAST(o.id AS STRING)                    AS order_number
        ,pr.product_key                         AS product_key
        ,cu.customer_key                        AS customer_key
        ,CAST(o.dwh_create_date AS DATE)        AS order_date   -- Since there is no date information on api, ingestion date used as order date.
        ,NULL                                   AS shipping_date
        ,NULL                                   AS due_date
        ,o.total_price                          AS total_sales_amount
        ,o.quantity                             AS quantity
        ,o.unit_price                           AS unit_price
        ,cu.data_source                         AS data_source
    FROM
        {{ ref('stg_djapi__order') }} o
        JOIN {{ ref('dim_customers') }} cu ON CAST(o.cust_id AS STRING) = REPLACE(cu.customer_id,'API-','') AND cu.data_source = 'api'
        JOIN {{ ref('dim_products') }} pr ON CAST(o.prd_id AS STRING) = REPLACE(pr.product_id,'API-','') AND pr.data_source = 'api'
) a