
/*

	Script: Findings on Bronze Data
	Script Purpose: This script includes queries to detect data inconsistencies in bronze tables. It also includes necessary actions notes for data standardization.

*/

-- >> CRM TABLES

	-- Table: crm_cust_info

		-- Col: cst_id
		-- There are 6 cst_id which has duplicate records.
		-- Action: Records with null id will be removed and records with latest create date will be kept.
		SELECT
			cst_id,
			COUNT(*)
		FROM
			bronze.crm_cust_info
		GROUP BY
			cst_id
		HAVING
			COUNT(*) > 1

		-- Col: cst_firstname & cst_lastname
		-- There are 26 records which has blank spaces in cst_firstname or cst_lastname column
		-- Action: First name and last name value will be trimmed.
		SELECT
			cst_id,
			cst_firstname,
			cst_lastname
		FROM	
			bronze.crm_cust_info
		WHERE
			cst_firstname != TRIM(cst_firstname)
			OR
			cst_lastname != TRIM(cst_lastname)
	
		-- Col: cst_marital_status
		-- There are 6 null records for marital status column. Also marital status is referred by symbol.
		-- Action: Symbols for marital status will be transformed meaningful text. (S -> Single, M -> Married)
		-- Null records will be transformed to 'n/a' since there is no available extra info in different tables about marital status.
		SELECT
			cst_marital_status,
			COUNT(*)
		FROM
			bronze.crm_cust_info
		GROUP BY
			cst_marital_status

		-- Col: cst_gndr
		-- There are 4577 null records for gender column. Also gender is referred by symbol.
		-- Action: Symbols for gender will be transformed meaningful text. (F -> Female, M -> Male)
		-- Null records will be filled with column gen of erp_cust_az12 table. Rest of the null records will be replaced with 'n/a'.
		SELECT
			cst_gndr,
			COUNT(*)
		FROM
			bronze.crm_cust_info
		GROUP BY
			cst_gndr

	-- Table: crm_prd_info

		SELECT * FROM bronze.crm_prd_info 

		-- Col: prd_id
		-- There is no duplicate records for prd_id column. No action needed.
		SELECT
			prd_id,
			COUNT(prd_id)
		FROM
			bronze.crm_prd_info
		GROUP BY
			prd_id
		HAVING
			COUNT(*) > 1

		-- Col: prd_key
		-- Production key has duplicates. This table has historical records about production of same product within various dates. No action needed
		SELECT
			prd_key,
			COUNT(prd_key)
		FROM
			bronze.crm_prd_info
		GROUP BY
			prd_key
		HAVING
			COUNT(1) > 1

		-- Col: prd_nm
		-- There are no blank spaces in product name category's value. No action needed
		SELECT
			prd_nm
		FROM
			bronze.crm_prd_info
		WHERE
			prd_nm != TRIM(prd_nm)

		-- Col: prd_cost
		-- There are 2 records which does not have cost.
		-- Action: NULL values will be replaced with 0.
		SELECT
			prd_id,
			prd_cost
		FROM
			bronze.crm_prd_info
		WHERE
			prd_cost IS NULL OR prd_cost <= 0

		-- Col: prd_line
		-- There are 17 null records.
		-- Action: Null values will be replaced with 'n/a'.
		SELECT
			prd_line,
			COUNT(*)
		FROM
			bronze.crm_prd_info
		GROUP BY
			prd_line

		-- Col: prd_start_dt & prd_end_dt
		-- There are 200 records which has inconsistent production date. (Production end date is before than production start date)
		-- Action: Production end date wil be set to one day before start of next production of the same product
		SELECT
			*
		FROM
			bronze.crm_prd_info
		WHERE
			prd_end_dt < prd_start_dt


	-- Table: crm_sales_details
		
		SELECT * FROM bronze.crm_sales_details

		-- Col: sls_ord_num
		-- There is no null or blank spaces in sls_ord_num column.
		SELECT
			sls_ord_num
		FROM
			bronze.crm_sales_details
		WHERE
			sls_ord_num IS NULL
			OR
			sls_ord_num != TRIM(sls_ord_num)

		-- Order number is repetitive.
		-- Action: 
		SELECT
			sls_ord_num,
			COUNT(*)
		FROM
			bronze.crm_sales_details
		GROUP BY
			sls_ord_num

		-- Col: sls_prd_key
		-- All category data has a match with crm_prd_info table.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_prd_key NOT IN (SELECT prd_key FROM bronze.crm_prd_info)

		-- Col: sls_cust_id
		-- All customer id data has a match with crm_cust_info table.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_cust_id NOT IN (SELECT cst_id FROM bronze.crm_cust_info)

		-- Col: sls_order_dt
		-- There are 19 order date which is not accurate (lower than 1900-01-01 or greater than 2026-05-23).
		-- Action: Inaccurate order dates will be replaced with NULL.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE 
			sls_order_dt IS NULL 
			OR sls_order_dt <= 19000000
			OR CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) >= GETDATE()

		-- There is not any order date later than shipment or due date.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE 
			sls_order_dt > sls_ship_dt
			OR
			sls_order_dt > sls_due_dt

		-- Col: sls_ship_dt
		-- There are no inaccurate shipping date.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE 
			sls_ship_dt IS NULL 
			OR sls_ship_dt <= 19000000
			OR CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) >= GETDATE()

		-- Col: sls_due_dt
		-- There are no inaccurate sales due date.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE 
			sls_due_dt IS NULL 
			OR sls_due_dt <= 19000000
			OR CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) >= GETDATE()

		-- Col: sls_quantity
		-- There is no inaccurate quantity value.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_quantity IS NULL
			OR sls_quantity <= 0

		-- Col: sls_price
		-- 12 records has inaccurate price.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_price IS NULL
			OR sls_price <= 0

		-- Col: sls_sales
		-- 28 records has invalid total.
		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_sales <= 0
			OR sls_sales IS NULL
			OR sls_sales != sls_quantity * sls_price

		
		-------------------------------------------- BURADA KALDIM -------------------------------------------------------

-- >> ERP TABLES
	-- Table: erp_cust_az12
	
		SELECT * FROM bronze.erp_cust_az12

		-- Col: cid
		-- There are no duplicate values on cid.
		SELECT
			cid,
			COUNT(*)
		FROM
			bronze.erp_cust_az12
		GROUP BY
			cid
		HAVING
			COUNT(*) > 1

		-- Col: bdate
		-- There is no out of range birthday date. However there are future birthday dates.
		-- Action: ??
		SELECT
			bdate
		FROM
			bronze.erp_cust_az12
		WHERE
			bdate < '1900-01-01'
			OR bdate > GETDATE()

		-- Col: gen
		-- Gender data is inconsistent. It includes following values: NULL, whitespace, M, F, Male, Female
		-- Action: NULL and whitespace values will be replaced with 'n/a'. Symbols will be converted to meaningful description. (F -> Female, M -> Male)
		SELECT
			gen,
			COUNT(*)
		FROM
			bronze.erp_cust_az12
		GROUP BY
			gen

	-- Table: erp_loc_a101
	
		SELECT * FROM bronze.erp_loc_a101

		-- Col: cid
		-- There are no duplicate values on cid.
		SELECT
			cid,
			COUNT(*)
		FROM
			bronze.erp_loc_a101
		GROUP BY
			cid
		HAVING
			COUNT(*) > 1

		-- Col: cntry
		-- There are abbreviations, whitespaces, country symbols and extended country names.
		-- Actions: Whitespaces and NULL values will be replaced with 'n/a'. Abbreviations will be replaced with extended country names.
		SELECT
			cntry,
			COUNT(*)
		FROM
			bronze.erp_loc_a101
		GROUP BY
			cntry
		HAVING
			COUNT(*) > 1


	-- Table: erp_px_cat_g1v2
	
		SELECT * FROM bronze.erp_px_cat_g1v2

		-- Col: id
		-- There is no whitespaces in id column. No action needed.
		SELECT 
			[id]
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			[id] != TRIM([id])

		-- Col: cat
		-- There is no whitespaces and inconsistent value in cat column. No action needed.
		SELECT 
			[cat]
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			[cat] != TRIM([cat])

		SELECT
			cat,
			COUNT(*)
		FROM
			bronze.erp_px_cat_g1v2
		GROUP BY
			cat

		-- Col: subcat
		-- There is no whitespaces and inconsistent value in subcat column. No action needed.
		SELECT 
			[subcat]
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			[subcat] != TRIM([subcat])

		SELECT
			[subcat],
			COUNT(*)
		FROM
			bronze.erp_px_cat_g1v2
		GROUP BY
			[subcat]

		-- Col: maintenance
		-- There is no whitespaces and inconsistent value in subcat column. No action needed.
		SELECT 
			maintenance
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			maintenance != TRIM(maintenance)

		SELECT
			maintenance,
			COUNT(*)
		FROM
			bronze.erp_px_cat_g1v2
		GROUP BY
			maintenance