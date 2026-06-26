SELECT
    COUNT(DISTINCT order_number) AS total_orders
FROM
    gold.fact_sales