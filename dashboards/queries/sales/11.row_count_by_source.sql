SELECT
    data_source
    ,SUM(total_sales_amount) AS total_sales
    ,COUNT(*)                AS order_count
FROM
    gold.fact_sales
GROUP BY
    data_source