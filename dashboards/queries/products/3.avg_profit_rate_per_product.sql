WITH revenue_per_order AS (
	SELECT
		p.product_name,
		AVG(s.unit_price) AS unit_price,
		AVG(p.cost) AS cost,
		AVG(s.unit_price) - AVG(p.cost) AS Revenue
	FROM
		gold.fact_sales s
		JOIN gold.dim_products p ON s.product_key = p.product_key AND p.cost > 0
	GROUP BY
		p.product_name
)

SELECT
	TRY_CAST(
		AVG( (Revenue / unit_price) * 100) 
	AS DECIMAL(10,2)) AS [Avgerage Revenue Rate]
FROM 
	revenue_per_order