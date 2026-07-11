WITH customer_ms AS (
    SELECT
        marital_status
        ,data_source
        ,SUM(CASE WHEN data_source = 'dummyjson-api' THEN 1 ELSE 0 END) AS api_count
        ,SUM(CASE WHEN data_source = 'crm-csv' THEN 1 ELSE 0 END) AS csv_count
    FROM 
        DataWarehouse.gold.dim_customers
    WHERE 
        birthdate IS NOT NULL
    GROUP BY
        marital_status
        ,data_source
)

SELECT
    marital_status AS [Marital Status]
    ,CAST(api_count * 100.0 / NULLIF(SUM(api_count) OVER(), 0) AS DECIMAL(5,2)) AS [API]
    ,CAST(csv_count * 100.0 / NULLIF(SUM(csv_count) OVER(), 0) AS DECIMAL(5,2)) AS [CSV]
FROM
    customer_ms