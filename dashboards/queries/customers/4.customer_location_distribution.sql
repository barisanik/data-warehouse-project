SELECT
	country AS [Country]
	,COUNT(customer_key) AS [Count]
FROM
    DataWarehouse.gold.dim_customers
GROUP BY
	country