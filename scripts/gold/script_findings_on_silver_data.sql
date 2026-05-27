
/*

	Script: Findings on Silver Data
	Script Purpose: This script includes queries to detect data inconsistencies between silver tables.

*/

-- >> Customer Dimension

    -- Customer ID
    -- Duplication check. No duplications found.
    SELECT
        cst.cst_id
        ,COUNT(*)
    FROM(
        SELECT 
            ci.[cst_id]
        FROM 
            [DataWarehouse].[silver].[crm_cust_info] ci
            LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
            LEFT JOIN silver.erp_loc_a101 el ON ci.cst_key = el.cid
    ) cst
    GROUP BY
        cst.cst_id
    HAVING
        COUNT(*) > 1

    -- Customer Key
    -- Duplication check. No duplications found.
    SELECT
        cst.cst_key
        ,COUNT(*)
    FROM(
        SELECT 
            ci.[cst_key]
        FROM 
            [DataWarehouse].[silver].[crm_cust_info] ci
            LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
            LEFT JOIN silver.erp_loc_a101 el ON ci.cst_key = el.cid
    ) cst
    GROUP BY
        cst.cst_key
    HAVING
        COUNT(*) > 1
       
    -- Gender
    -- 6072 mismatch found between ERP and CRM datasets.
    SELECT 
        ci.[cst_id]
        ,ci.[cst_gndr]
        ,ca.gen
    FROM 
        [DataWarehouse].[silver].[crm_cust_info] ci
        LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
        LEFT JOIN silver.erp_loc_a101 el ON ci.cst_key = el.cid
    WHERE
        TRIM(LOWER(ci.cst_gndr)) != TRIM(LOWER(ca.gen))


-- >> Product Dimension

    -- Product Key
    -- Duplication check. No duplications found.
    SELECT 
        a.product_key, COUNT(*)
    FROM(
        SELECT
            cp.prd_id AS ID
            ,cp.prd_key AS product_key
        FROM
            silver.crm_prd_info cp
            LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
        WHERE
            cp.prd_end_dt IS NULL
    ) a
    GROUP BY a.product_key
    HAVING COUNT(*) > 1