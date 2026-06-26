-- Average Revenue per Customer
SELECT
    SUM(s.total_sales_amount) / COUNT(DISTINCT s.customer_key) AS avg_revenue_per_customer
FROM
    gold.fact_sales s