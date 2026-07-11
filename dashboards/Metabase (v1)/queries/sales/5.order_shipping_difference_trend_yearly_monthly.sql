-SELECT
	FORMAT(shipping_date, 'yyyy-MM') AS [Year - Month]
	,AVG(DATEDIFF(DAY,order_date,shipping_date)) AS [Order - Shipping Date Difference]
FROM
	[gold].[fact_sales]
WHERE
	order_date IS NOT NULL
	AND shipping_date IS NOT NULL
GROUP BY
	FORMAT(shipping_date, 'yyyy-MM')
ORDER BY
	FORMAT(shipping_date, 'yyyy-MM')