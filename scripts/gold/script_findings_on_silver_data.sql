
/*
    ====================================================
	Script: Findings on Silver Data
	Script Purpose: This script includes queries to detect data inconsistencies between silver tables.
    Author: Baris Anik
    ====================================================

    COMMENT HIERARCHY:
	====================================================
	-- >> Dimension
		-- Columns
		-- Findings
		-- Actions

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

    SELECT
        *
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id

    -- Col: Category ID
    -- Findings: No abnormality found.
    SELECT
        prd_id
        ,cat_id
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        cat_id IS NULL
        OR LEN(TRIM(cat_id)) != LEN (cat_id)

    -- Col: Product Key
    -- Findings: No duplications found.
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

    SELECT 
        a.product_key, COUNT(*)
    FROM(
        SELECT
            dp.id AS ID
            ,dp.pkey AS product_key
        FROM
            silver.djapi_product dp
    ) a
    GROUP BY a.product_key
    HAVING COUNT(*) > 1

    -- Product Name
    -- Findings: No abnormality found.
    SELECT
        cp.prd_id
        ,cp.prd_nm
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        cp.prd_nm IS NULL
        OR LEN(TRIM(cp.prd_nm)) != LEN (cp.prd_nm)

    SELECT
        id
        ,title
    FROM
        silver.djapi_product dp
    WHERE
        title IS NULL
        OR LEN(TRIM(title)) != LEN (title)

    -- Col: Product Cost
    -- Findings: There are 2 records which does not have cost. No actions needed.
    SELECT
        cp.prd_id AS ID
        ,CAST(cp.prd_cost AS DECIMAL(10,2))
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        cp.prd_cost IS NULL
        OR CAST(cp.prd_cost AS DECIMAL(10,2)) <= 0

    -- Col: Production Line
    -- Findings: No inconsistency found on prd_line values.
    SELECT
        cp.prd_line
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        prd_line IS NULL
        OR LEN(TRIM(prd_line)) != LEN (prd_line)
        OR prd_line = ' '

    -- Col: Production Start Date & Production End Date
    -- Findings: No inconsistency found on prd_start_dt and prd_end_dt values.
    SELECT
        cp.prd_id
        ,cp.prd_start_dt
        ,cp.prd_end_dt
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        cp.prd_end_dt < prd_start_dt
        OR prd_start_dt IS NULL

    -- Col: Category
    -- Findings: There are 7 records with NULL category from crm and erp sources.
    -- Actions: NULL values will be replaced with 'n/a'.
    SELECT
        cat
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        cat IS NULL
        OR LEN(TRIM(cat)) != LEN (cat)

    SELECT
        cat,
        COUNT(*)
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    GROUP BY
        cat

    SELECT
        *
    FROM
        silver.djapi_product
    WHERE
        category IS NULL
        OR LEN(TRIM(category)) != LEN (category)
        OR category = ' '

    SELECT
        category,
        COUNT(*)
    FROM
        silver.djapi_product
    GROUP BY
        category

    -- Col: Subcat
    -- Findings: There are 7 records with NULL sub-category from crm and erp sources.
    -- Actions: NULL values will be replaced with 'n/a'.
    SELECT
        subcat
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        subcat IS NULL
        OR LEN(TRIM(subcat)) != LEN (subcat)

    SELECT
        subcat,
        COUNT(*)
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    GROUP BY
        subcat

    -- Col: Maintenance
    -- Findings: There are 7 records with NULL maintenance from crm and erp sources.
    -- Actions: NULL values will be replaced with 'n/a'.
    SELECT
        maintenance
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    WHERE
        maintenance IS NULL
        OR LEN(TRIM(maintenance)) != LEN (maintenance)

    SELECT
        maintenance,
        COUNT(*)
    FROM
        silver.crm_prd_info cp
        LEFT JOIN silver.erp_px_cat_g1v2 prc ON cp.cat_id = prc.id
    GROUP BY
        maintenance