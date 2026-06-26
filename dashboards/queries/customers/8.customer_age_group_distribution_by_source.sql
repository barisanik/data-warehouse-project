WITH customer_ages AS (
    SELECT
        customer_key,
        birthdate,
        data_source,
        DATEDIFF(YEAR, birthdate, GETDATE()) - 
        CASE 
            WHEN MONTH(birthdate) > MONTH(GETDATE()) OR (MONTH(birthdate) = MONTH(GETDATE()) AND DAY(birthdate) > DAY(GETDATE())) 
            THEN 1 
            ELSE 0 
        END AS age
    FROM DataWarehouse.gold.dim_customers
    WHERE birthdate IS NOT NULL
),
customer_segments AS (
    SELECT
        customer_key,
        data_source,
        CASE
            WHEN age BETWEEN 18 AND 24 THEN '18-24'
            WHEN age BETWEEN 25 AND 34 THEN '25-34'
            WHEN age BETWEEN 35 AND 44 THEN '35-44'
            WHEN age BETWEEN 45 AND 54 THEN '45-54'
            WHEN age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group
    FROM customer_ages
),
aggregated_counts AS (
    -- Sum of counts group by age group.
    SELECT
        age_group,
        SUM(CASE WHEN data_source = 'dummyjson-api' THEN 1 ELSE 0 END) AS api_count,
        SUM(CASE WHEN data_source = 'crm-csv' THEN 1 ELSE 0 END) AS csv_count
    FROM 
        customer_segments
    GROUP BY 
        age_group
)

SELECT
    age_group AS [Age Group],
    CAST(api_count * 100.0 / NULLIF(SUM(api_count) OVER(), 0) AS DECIMAL(5,2)) AS [API],
    CAST(csv_count * 100.0 / NULLIF(SUM(csv_count) OVER(), 0) AS DECIMAL(5,2)) AS [CSV]
FROM
    aggregated_counts
ORDER BY
    CASE age_group
        WHEN '18-24' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        ELSE 6
    END;