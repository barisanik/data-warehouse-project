SELECT
    c.country
	,f.[data_source]
    ,SUM(f.total_sales_amount) AS total_sales
FROM
    gold.fact_sales f
    JOIN gold.dim_customers c ON f.customer_key = c.customer_key
WHERE
    c.country != 'n/a'
GROUP BY
    c.country
	,f.[data_source]
ORDER BY
    total_sales DESC