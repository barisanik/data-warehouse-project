/*
    # ============================================================================ #
        DDL Script: Create gold dimensions and facts
    # ============================================================================ #

    Script Purpose: This script includes view creation commands for gold layer.
    
*/

-- Dim: Customer
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY a.customer_id, a.[data_source]) AS customer_key
    ,CASE
        WHEN [data_source] = 'crm-csv' THEN CONCAT('CSV-', CAST(a.[customer_id] AS VARCHAR(20)))
        WHEN [data_source] = 'dummyjson-api' THEN CONCAT('API-', CAST(a.[customer_id] AS VARCHAR(20)))
        ELSE 'Unknown'
    END AS [customer_id]
    ,customer_number
    ,first_name
    ,last_name
    ,country
    ,marital_status
    ,gender
    ,birthdate
    ,create_date
    ,[data_source]
FROM(
    SELECT 
        ci.[cst_id] AS customer_id
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
        ,TRY_CAST(ci.[cst_create_date] AS DATE) AS create_date
        ,'crm-csv' AS [data_source]
    FROM 
        [DataWarehouse].[silver].[crm_cust_info] ci
        LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
        LEFT JOIN silver.erp_loc_a101 el ON ci.cst_key = el.cid

    UNION ALL

    SELECT
        djc.[id] AS customer_id
        ,'n/a' AS customer_number
        ,djc.[first_name] AS first_name
        ,djc.[last_name] AS last_name
        ,djc.[country] AS country
        ,'n/a' AS [marital_status]
        ,djc.[gender] AS [gender] -- Normalized in silver layer
        ,djc.[birthdate] AS [birthdate]
        ,TRY_CAST(djc.[dwh_create_date] AS DATE) AS [create_date]
        ,'dummyjson-api' AS [data_source]
    FROM
        [DataWarehouse].[silver].[djapi_customer] djc
) a;

GO

-- Dim: Product
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS 
    SELECT
        ROW_NUMBER() OVER( ORDER BY a.[product_id], a.[data_source]) AS product_key
        ,CASE
            WHEN [data_source] = 'erp-csv' THEN CONCAT('CSV-', CAST(a.product_id AS VARCHAR(20)))
            WHEN [data_source] = 'dummyjson-api' THEN CONCAT('API-', CAST(a.product_id AS VARCHAR(20)))
            ELSE 'Unknown'
        END AS product_id
        ,product_number
        ,product_name
        ,category_id
        ,CASE
            WHEN category IS NULL THEN 'n/a'
            ELSE category
        END AS category
        ,subcategory
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
        ,[start_date]
        ,[data_source]
    FROM(
        SELECT
            -- Product identity
            cp.prd_id AS product_id
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
            ,'erp-csv' AS [data_source]
        FROM
            silver.crm_prd_info cp
            LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
        WHERE
            cp.prd_end_dt IS NULL -- Keep only last records with avoiding historical records.

        UNION ALL

        SELECT
            dp.id AS product_id
            ,dp.pkey AS product_number
            ,dp.title AS product_name
            ,LEFT(dp.pkey,3) AS category_id
            ,dp.category AS category
            ,NULL AS subcategory
            ,NULL AS maintenance
            ,NULL AS cost
            ,NULL AS product_line
            ,dp.createdAt AS [start_date]
            ,'dummyjson-api' AS [data_source]
        FROM
            silver.djapi_product dp
    ) a;
GO

-- Fact: Sales