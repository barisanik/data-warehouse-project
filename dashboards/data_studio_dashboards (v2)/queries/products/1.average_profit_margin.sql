/*
	Custom Query: 	Average Profit Margin
	Dashboard: 		DWH Products (Data Studio)
	Purpose: 		Calculates the arithmetic average of individual product profit margins for products with a valid cost (> 0).
	Formula: 		APM = Average of (Total Profit / Total Unit Price)
    Warning:        Replace GCP_PROJECT_ID with your actual Google Cloud Project ID in the query before executing it.
*/

WITH revenue_per_order AS (
    SELECT
        p.product_name
        ,AVG(s.unit_price) AS unit_price
        ,AVG(p.cost) AS cost
        ,AVG(s.unit_price) - AVG(p.cost) AS profit
    FROM
        `GCP_PROJECT_ID.gold.fact_sales` s
        JOIN `GCP_PROJECT_ID.gold.dim_products` p ON s.product_key = p.product_key AND p.cost > 0
    GROUP BY
        p.product_name
)
SELECT
    ROUND(AVG(SAFE_DIVIDE(profit, unit_price)), 2) AS avg_profit_margin_pct
FROM
    revenue_per_order