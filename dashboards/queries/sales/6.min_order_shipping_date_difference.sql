SELECT
	MIN(DATEDIFF(DAY,order_date,shipping_date)) AS [Min Order - Shipping Date Difference]
FROM
	[gold].[fact_sales]
WHERE
	order_date IS NOT NULL
	AND shipping_date IS NOT NULL