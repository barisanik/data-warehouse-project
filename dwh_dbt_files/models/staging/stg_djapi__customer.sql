/*
	# ============================================================================ #
		Model: Staging API Customer Info
	# ============================================================================ #

    Script Purpose: This script loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Removal of prefix and whitespaces for customer id (id).
    - Initial capitilization and whitespace removal for first name (first_name), last name (last_name).
    - Mapping gender statements with long format names.
    - Replacement of invalid birthdate with NULL.
    - Initial capitalization for city, state and country

    Run Command: dbt run --select stg_djapi__customer
    Test Command: dbt test --select stg_djapi__customer

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_djapi__customer' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_api', 'djapi_customer') }}
),
cleaned AS(
    SELECT
        CAST(TRIM(REPLACE(id,'dummy-','')) AS INT64) AS id -- Clear prefix.
        ,IFNULL({{ fn_initcap('first_name') }}, 'n/a') AS first_name
        ,IFNULL({{ fn_initcap('last_name') }}, 'n/a') AS last_name
        ,CASE 
            WHEN (gender IS NULL OR gender = '') THEN 'n/a' -- Replace NULL value or empty string with string 'n/a'.
            WHEN UPPER(TRIM(gender)) IN ('M','MALE') THEN 'Male'
            WHEN UPPER(TRIM(gender)) IN ('F','FEMALE') THEN 'Female'
            ELSE 'n/a'
        END AS gender
        ,CASE								-- Set future and out-of-range birthday dates to NULL.
            WHEN (SAFE_CAST(birthdate AS DATE) < '1900-01-01' OR SAFE_CAST(birthdate AS DATE) > DATE_SUB(CURRENT_DATE(), INTERVAL 18 YEAR)) THEN NULL
            ELSE SAFE_CAST(birthdate AS DATE)
        END AS birthdate
        ,{{ fn_initcap('city') }} AS city -- Set first character of each word uppercase.
        ,{{ fn_initcap('state') }} AS state -- Set first character of each word uppercase.
        ,UPPER(TRIM(state_code)) AS state_code -- Convert to uppercase.
        ,INITCAP(REPLACE(country, '\r', '')) AS country -- Set first character of each word uppercase.
        ,CURRENT_TIMESTAMP() AS dwh_create_date
    FROM
        source
)

SELECT * FROM cleaned