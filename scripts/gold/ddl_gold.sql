/*
    # ============================================================================ #
        DDL Script: Create gold dimensions and facts
    # ============================================================================ #

    Script Purpose: This script includes view creation commands for gold layer.
    
*/

-- Dim: Customer
CREATE VIEW gold.dim_customers AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key
    ,ci.[cst_id] AS customer_id
    ,ci.[cst_key] AS customer_number
    ,ci.[cst_firstname] AS first_name
    ,ci.[cst_lastname] AS last_name
    ,el.cntry AS country
    ,ci.[cst_marital_status] AS marital_status
    ,CASE       -- If not null then CRM data source will be used as source.
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.gen,'n/a')
    END AS gender
    ,ca.bdate AS birthdate
    ,ci.[cst_create_date] AS create_date
FROM 
    [DataWarehouse].[silver].[crm_cust_info] ci
    LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
    LEFT JOIN silver.erp_loc_a101 el ON ci.cst_key = el.cid;


-- Dim: Product
CREATE VIEW gold.dim_products AS 
SELECT
    ROW_NUMBER() OVER( ORDER BY cp.prd_start_dt, cp.prd_key) AS product_key
    -- Product identity
    ,cp.prd_id AS product_id
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
    ,cp.prd_start_dt AS [start_date]
FROM
    silver.crm_prd_info cp
    LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
WHERE
    cp.prd_end_dt IS NULL; -- Keep only last records with avoiding historical records.