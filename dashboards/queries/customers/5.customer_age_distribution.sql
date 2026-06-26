WITH customer_ages AS (
    SELECT
        customer_key,
        birthdate,
        -- Calculate age of customer
        DATEDIFF(YEAR, birthdate, GETDATE()) - 
        CASE 
            WHEN MONTH(birthdate) > MONTH(GETDATE()) OR 
                 (MONTH(birthdate) = MONTH(GETDATE()) AND DAY(birthdate) > DAY(GETDATE())) 
            THEN 1 
            ELSE 0 
        END AS age
    FROM
        DataWarehouse.gold.dim_customers
    WHERE 
        birthdate IS NOT NULL
),
customer_segments AS (
    SELECT
        customer_key,
        age,
        CASE    -- Age group classification of every customer
            WHEN age BETWEEN 18 AND 24 THEN '18-24'
            WHEN age BETWEEN 25 AND 34 THEN '25-34'
            WHEN age BETWEEN 35 AND 44 THEN '35-44'
            WHEN age BETWEEN 45 AND 54 THEN '45-54'
            WHEN age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group
    FROM
        customer_ages
)

SELECT
    age_group AS [Age Group]
    ,COUNT(customer_key) AS [Customer Count]
    ,TRY_CAST(TRY_CAST(COUNT(customer_key) AS DECIMAL(10,2)) / SUM(COUNT(customer_key)) OVER() * 100 AS DECIMAL(10,2)) AS [Percentage]
FROM
    customer_segments
GROUP BY
    age_group
ORDER BY
    CASE age_group
        WHEN '18-24' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55-64' THEN 5
        ELSE 6
    END;