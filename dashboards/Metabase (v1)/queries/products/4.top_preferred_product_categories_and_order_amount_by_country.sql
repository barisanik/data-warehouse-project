WITH category_preference_by_country AS(
	SELECT
		c.country
		,p.category
		,COUNT(p.category) AS [Count]
		,ROW_NUMBER() OVER (PARTITION BY country ORDER BY COUNT(p.category) DESC) AS rn
	FROM
		gold.fact_sales s
		JOIN gold.dim_products p ON p.product_key = s.product_key
		JOIN gold.dim_customers c ON c.customer_key = s.customer_key
	GROUP BY
		c.country
		,p.category
)

SELECT
	country AS [Country]
	,category AS [Category]
	,[Count]
FROM
	category_preference_by_country
WHERE
	rn = 1 
	AND country != 'n/a'