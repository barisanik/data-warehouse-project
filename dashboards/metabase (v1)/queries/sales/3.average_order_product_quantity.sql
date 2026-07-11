SELECT
    CAST(AVG(total_sales_amount) AS DECIMAL(10,2)) AS avg_order_value
FROM
    gold.fact_sales