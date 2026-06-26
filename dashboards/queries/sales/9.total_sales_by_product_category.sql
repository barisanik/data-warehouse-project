SELECT TOP 10
    p.category
    ,SUM(f.total_sales_amount) AS total_sales
	,f.[data_source]		   AS [data_source]
FROM
    gold.fact_sales f
    JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE
    p.category != 'n/a'
GROUP BY
    p.category
	,f.[data_source]
ORDER BY
    total_sales DESC