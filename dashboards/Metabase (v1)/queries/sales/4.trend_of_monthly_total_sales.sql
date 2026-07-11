SELECT
    FORMAT(order_date, 'yyyy-MM') AS [month]
    ,SUM(total_sales_amount)      AS total_sales
FROM
    gold.fact_sales
WHERE
    order_date IS NOT NULL
GROUP BY
    FORMAT(order_date, 'yyyy-MM')
ORDER BY
    [month]