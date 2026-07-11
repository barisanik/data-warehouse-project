SELECT
	COUNT(customer_key) AS current_cust_count
FROM
	DataWarehouse.gold.dim_customers