/*
	# ============================================================================ #
		Stored Procedure: Load silver layer
	# ============================================================================ #

	Script Purpose: This script performs truncation, transformaiton and a insert operation to created tables utilizing source tables of bronze layer.
		
	Usage Example:
	- EXEC bronze.load_silver;

	WARNING: This script will truncate the target tables before loading data, which will cause loss of existing data in those tables.
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- Loading silver.crm_cust_info
        SET @start_time = GETDATE();
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info';

		INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gndr,
			cst_create_date
		)
		SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,	-- Trimmed first name to avoid whitespaces.
			TRIM(cst_lastname) AS cst_lastname,		-- Trimmed last name to avoid whitespaces.
			CASE UPPER(TRIM(cst_marital_status))	-- Map marital status codes to descriptions; default NULL/unknown values to 'n/a'.
				WHEN 'S' THEN 'Single'
				WHEN 'M' THEN 'Married'
				ELSE 'n/a'
			END AS cst_marital_status,
			CASE UPPER(TRIM(cst_gndr))				-- Converted gender symbols to text, replaced null with n/a.
				WHEN 'F' THEN 'Female'
				WHEN 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gndr,
			cst_create_date
		FROM(
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS creation_order
			FROM
				bronze.crm_cust_info
			WHERE
				cst_id IS NOT NULL -- Filtered out records with NULL cst_id values.
		) a
		WHERE
			a.creation_order = 1 -- Retained only the latest record per customer to remove historical duplicates.

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Loading silver.crm_prd_info
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT '>> Inserting Data Into: silver.crm_prd_info'; 

	INSERT INTO silver.crm_prd_info(
		prd_id,
		cat_id,		-- Extracted from 'prd_key' column.
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)
	SELECT 
		prd_id
		,REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id  -- Extracted the first 5 characters of product key as category code. Converted dash to underscore to join it with the ERP category table.
		,SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key		-- Extracted the remaining part of the product key, to join with 'sls_prd_key' column of crm_sales_details.
		,prd_nm
		,ISNULL(prd_cost, 0) AS prd_cost                    -- Replaced NULL values with zero.
		,CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_line
		,CAST(prd_start_dt AS DATE) AS prd_start_dt         -- Casted to DATE because the column does not contain time component.
		,CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt -- Calculated the production end date as one day prior to the next production start date. Casted to DATE for consistency.
	FROM 
		bronze.crm_prd_info

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Loading silver.crm_sales_details
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;
	PRINT '>> Inserting Data Into: silver.crm_sales_details'; 

	INSERT INTO 
	silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
	)
	SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE	-- Validated dates to prevent out of range or future date inserts.
			WHEN sls_order_dt IS NULL OR sls_order_dt <= 19000000 OR CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) >= CAST(GETDATE() AS DATE) THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt,
		CASE
			WHEN sls_ship_dt IS NULL OR sls_ship_dt <= 19000000 OR CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) >= CAST(GETDATE() AS DATE) THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END AS sls_ship_dt,
		CASE
			WHEN sls_due_dt IS NULL OR sls_due_dt <= 19000000 OR CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) >= CAST(GETDATE() AS DATE) THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END AS sls_due_dt,
		CASE	-- Derived sales amount with (unit price x quantity) formula where the original value is NULL or less than or equal to zero.
			WHEN (sls_sales IS NULL OR sls_sales <= 0) AND sls_price IS NOT NULL THEN ISNULL(sls_quantity,1) * ABS(sls_price)
			ELSE sls_sales
		END AS sls_sales,
		ABS(ISNULL(sls_quantity,1)) AS sls_quantity, -- Avoided zero, negative and null quantity value.
		CASE	-- Derived price value with (total sales price / quantity) formula where the original value is NULL, zero, or negative.
			WHEN (sls_price IS NULL OR sls_price = 0) AND (sls_quantity IS NOT NULL AND sls_quantity != 0) AND (sls_sales IS NOT NULL) THEN sls_sales / sls_quantity
			WHEN sls_price < 0 THEN ABS(sls_price) -- Converted negative value to positive with absolute function.
			ELSE sls_price
		END AS sls_price
	FROM
		bronze.crm_sales_details

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	PRINT '------------------------------------------------';
	PRINT 'Loading ERP Tables';
	PRINT '------------------------------------------------';

	-- Loading silver.erp_cust_az12
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT '>> Inserting Data Into: silver.erp_cust_az12';

	INSERT INTO silver.erp_cust_az12(
		cid,
		bdate,
		gen
	)
	SELECT
		CASE								-- Remove 'NAS' prefix
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) 
			ELSE cid
		END AS cid, 
		CASE								-- Set future and out-of-range birthday dates to NULL.
			WHEN (bdate < '1900-01-01' OR (bdate > DATEADD( YEAR, -18, GETDATE() ))) THEN NULL
			ELSE bdate
		END AS bdate,
		CASE UPPER(TRIM(COALESCE(gen,'')))	-- Replace gender values
			WHEN '' THEN 'n/a'
			WHEN 'F' THEN 'Female'
			WHEN 'M' THEN 'Male'
			ELSE gen
		END AS gen
	FROM
		bronze.erp_cust_az12

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';


	-- Loading silver.erp_loc_a101
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT '>> Inserting Data Into: silver.erp_loc_a101';

	INSERT INTO silver.erp_loc_a101(
		cid,
		cntry
	)
	SELECT
		REPLACE(cid,'-','') AS cid,				-- Remove dash character from id.
		CASE TRIM(UPPER(COALESCE(cntry, '')))	-- Normalize and handle missing or blank country codes.
			WHEN 'US' THEN 'United States'
			WHEN 'USA' THEN 'United States'
			WHEN 'DE' THEN 'Germany'
			WHEN 'AU' THEN 'Australia'
			WHEN 'AUS' THEN 'Australia'
			WHEN 'CA' THEN 'Canada'
			WHEN 'CAN' THEN 'Canada'
			WHEN 'FR' THEN 'France'
			WHEN 'UK' THEN 'United Kingdom'
			WHEN '' THEN 'n/a'
			ELSE TRIM(cntry)
		END AS cntry
	FROM
		bronze.erp_loc_a101

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';


	-- Loading silver.erp_px_cat_g1v2
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';

	INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT -- Direct load without transformation.
		id,
		cat,
		subcat,
		maintenance
	FROM
		bronze.erp_px_cat_g1v2

	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	SET @batch_end_time = GETDATE();

	PRINT '=========================================='
	PRINT 'Loading Silver Layer is Completed';
    PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	PRINT '=========================================='

	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END