SELECT
	gender AS [Gender]
	,COUNT(customer_key) AS [Count]
FROM
    DataWarehouse.gold.dim_customers
GROUP BY
	gender