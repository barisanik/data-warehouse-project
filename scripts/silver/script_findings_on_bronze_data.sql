
/*

	Script: Findings on Bronze Data
	Script Purpose: This script includes queries to detect data inconsistencies in bronze tables. It also includes necessary actions notes for data standardization.


	SUMMARY OF FINDINGS
	====================================================
	# 1. CRM Tables
		1.1. crm_cust_info: Duplicate IDs, whitespaces on first name and last name columns. NULLS and abbreviations on gender and marital status columns.
		1.2. crm_prd_info: NULL on prd_cost and prd_line columns. 200 records has inconsistencies about production date.
		1.3. crm_sales_details: Negative or NULL sls_price values.
	# 2. ERP Tables
		2.1. erp_cust_az12: Abbreviations on gender.
		2.2. erp_loc_a101: Abbreviations on country(cntry).
		2.3. erp_px_cat_g1v2: No inconsistent data.
	# 3. API Tables
		3.1. djapi_product: Unnecessary prefixes, NULLs and whitespaces on ID. Inconsistent capitalization, whitespaces and NULLs on title, category and pkey. Suffixes on pkey.
		3.2. djapi_user: Unnecessary prefixes, NULLs and whitespaces on ID. Inconsistent capitalization, whitespaces and NULLs on first_name, last_name and gender.

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
			LEN(cst_firstname) != LEN(TRIM(cst_firstname))
			OR
			LEN(cst_lastname) != LEN(TRIM(cst_lastname))
	
		-- Col: cst_marital_status
		-- There are 6 null records for marital status column. Also marital status is abbreviated by S and M characters.
		-- Action: Abbreviations for marital status will be transformed meaningful text. (S -> Single, M -> Married)
		-- Null records will be transformed to 'n/a' since there is no available extra info in different tables about marital status.
		SELECT
			cst_marital_status,
			COUNT(*)
		FROM
			bronze.crm_cust_info
		GROUP BY
			cst_marital_status

		-- Col: cst_gndr
		-- There are 4577 null records (24.74%) for gender column. Also gender is abbreviated with F and M characters.
		-- Action: Abbreviations for gender will be transformed meaningful text. (F -> Female, M -> Male)
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
			LEN(prd_nm) != LEN(TRIM(prd_nm))

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
			LEN(sls_ord_num) != LEN(TRIM(sls_ord_num))

		-- Order number is repetitive. However this is not inconsistency. It is seen that more than one product can be in the same order.
		-- Action: No action needed.
		SELECT
			sls_ord_num,
			COUNT(*)
		FROM
			bronze.crm_sales_details
		GROUP BY
			sls_ord_num

		SELECT
			*
		FROM
			bronze.crm_sales_details
		WHERE
			sls_ord_num = 'SO55367'

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

-- >> ERP TABLES
	-- Table: erp_cust_az12
	
		SELECT * FROM bronze.erp_cust_az12

		-- Col: cid
		-- There are no duplicate values on cid. All data has match with customer key with crm_cust_info table.
		SELECT
			cid,
			COUNT(*)
		FROM
			bronze.erp_cust_az12
		GROUP BY
			cid
		HAVING
			COUNT(*) > 1

		SELECT
			*
		FROM
			bronze.erp_cust_az12 ec
			LEFT JOIN bronze.crm_cust_info cc ON REPLACE(ec.cid,'NAS','') = cc.cst_key 
		WHERE
			REPLACE(ec.cid,'NAS','') != cc.cst_key 

		-- Col: bdate
		-- There is no out of range birthday date. However there are future birthday dates.
		-- Action: NULL values and birthdates shows under 18 years old age will be converted to NULL.
		SELECT
			bdate
		FROM
			bronze.erp_cust_az12
		WHERE
			bdate < '1900-01-01'
			OR bdate > GETDATE()
			OR bdate > DATEADD( YEAR, -18, GETDATE() )

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


	-- Table: erp_px_cat_g1v2
	
		SELECT * FROM bronze.erp_px_cat_g1v2

		-- Col: id
		-- There is no whitespaces in id column. No action needed.
		SELECT 
			[id]
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			LEN([id]) != LEN(TRIM([id]))

		-- Col: cat
		-- There is no whitespaces and inconsistent value in cat column. No action needed.
		SELECT 
			[cat]
		FROM 
			bronze.erp_px_cat_g1v2
		WHERE
			LEN([cat]) != LEN(TRIM([cat]))

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
			LEN([subcat]) != LEN(TRIM([subcat]))

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
			LEN(maintenance) != LEN(TRIM(maintenance))

		SELECT
			maintenance,
			COUNT(*)
		FROM
			bronze.erp_px_cat_g1v2
		GROUP BY
			maintenance

-- >> API TABLES
	-- Table: djapi_product
		
		SELECT
			*
		FROM
			bronze.djapi_product

		-- Col: id
		-- Some of id's has prefix 'dummy-' and some of them starts with '00'. Also whitespaces found on both sides. There is no duplication on column 'id'.
		-- Actions: Whitespaces and prefixes will be avoided.
		SELECT
			id
		FROM
			bronze.djapi_product

		SELECT
			id,
			COUNT(id)
		FROM
			bronze.djapi_product
		GROUP BY
			id
		HAVING
			COUNT(*) > 1

		SELECT
			id
		FROM
			bronze.djapi_product
		WHERE
			TRY_CONVERT(INT, id) IS NULL 

		SELECT
			id
		FROM
			bronze.djapi_product
		WHERE
			LEN(id) != LEN(TRIM(id))

		-- Col: title
		-- There are 25 records includes unnecessary whitespaces or NULL values. Also improper capitalization found on some records.
		-- Actions: Whitespaces will be removed from title. Capitalization will be fixed with initcap function. NULL products will be excluded.
		SELECT 
			title
		FROM
			bronze.djapi_product
		WHERE
			title IS NULL
			OR LEN(title) != LEN(TRIM(title))

		-- Col: category
		-- There are NULL records and whitespaces on title. Improper capitalization and dash character found between words was found. (Ex: kitchen-accessories)
		-- Actions: Whitespaces will be removed from title. Capitalization will be fixed with initcap function. NULL products will be excluded.
		SELECT 
			category
		FROM
			bronze.djapi_product
		WHERE
			category IS NULL
			OR LEN(category) != LEN(TRIM(category))

		-- Col: pkey
		-- Capitalization issues found on some keys. Also there are 27 records which has unnecessary suffix.
		-- Actions: All keys will be uppercased. Unnecessary suffixes will be removed.
		SELECT
			pkey
		FROM
			bronze.djapi_product
		
		SELECT
			id,
			pkey
		FROM
			bronze.djapi_product
		WHERE
			LEN(pkey) != LEN(TRIM(pkey))

		SELECT 
			pkey
			,LEN(pkey)
		FROM
			bronze.djapi_product
		GROUP BY
			pkey
		HAVING LEN(pkey) > 15

	-- Table: djapi_user

		SELECT * FROM bronze.djapi_user

		-- Col: id
		-- Same issues found on id column with id column of djapi_user table. There is no duplication on column 'id'.
		-- Actions: Whitespaces and prefixes will be avoided.
		SELECT
			id
		FROM
			bronze.djapi_user

		SELECT
			id,
			COUNT(id)
		FROM
			bronze.djapi_user
		GROUP BY
			id
		HAVING
			COUNT(*) > 1

		SELECT
			id
		FROM
			bronze.djapi_user
		WHERE
			TRY_CONVERT(INT, id) IS NULL

		SELECT
			id
		FROM
			bronze.djapi_user
		WHERE
			LEN(id) != LEN(TRIM(id))

		-- Col: first_name and last_name
		-- Findings: Whitespaces, NULL variables, improper capitalization.
		-- Actions: NULL values will be replaced with 'n/a'. Whitespaces will be removed and capitalization will be fixed.
		SELECT
			first_name,
			last_name
		FROM
			bronze.djapi_user
		WHERE
			LEN(first_name) != LEN(TRIM(first_name))
			OR LEN(last_name) != LEN(TRIM(last_name))
			OR first_name IS NULL
			OR last_name IS NULL

		-- Col: gender
		-- Gender value has variations on bronze data. Findings: whitespaces as prefix or suffix and NULL values.
		-- Actions: Whitespaces will be trimmed. First letter of gender statement will be uppercase. NULL statements will replaced with 'n/a'
		SELECT
			gender,
			COUNT(*)
		FROM
			bronze.djapi_user
		GROUP BY
			gender

		-- Col: birthdate
		-- There is no out of range or future birthday date.
		SELECT
			birthdate
		FROM
			bronze.djapi_user
		WHERE
			birthdate < '1900-01-01'
			OR birthdate > GETDATE()

		-- Col: city
		-- There is no corruption on column 'city'.
		SELECT
			city
		FROM
			bronze.djapi_user
		WHERE
			LEN(city) != LEN(TRIM(city))
			OR city IS NULL

		SELECT
			city,
			COUNT(city)
		FROM
			bronze.djapi_user
		GROUP BY
			city
		HAVING
			COUNT(*) > 1

		SELECT
			city
		FROM
			bronze.djapi_user
		WHERE
			LEN(city) != LEN(TRIM(city))
			OR city IS NULL