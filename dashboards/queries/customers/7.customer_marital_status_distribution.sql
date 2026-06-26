SELECT
	marital_status AS [Marital Status]
	,COUNT(customer_key) AS [Count]
FROM
    DataWarehouse.gold.dim_customers
GROUP BY
	marital_status