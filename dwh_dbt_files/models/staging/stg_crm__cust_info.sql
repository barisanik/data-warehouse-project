/*
	# ============================================================================ #
		Model: Staging CRM Customer Info
	# ============================================================================ #

    Script Purpose: This script performs transformation and loads data into the silver layer utilizing source tables of bronze layer.

    Transformation processes:
    - Deduplication on historical records of customers by cst_id. Latest records will be kept.
    - Trimming whitespaces on cst_firstname and cst_lastname columns.
    - Mapping on marital status values (M -> Married, S -> Single, NULL -> n/a).
    - Mapping on gender values (M -> Male, F -> Female, NULL -> n/a).
    
    Run Command: dbt run --select stg_crm__cust_info
    Test Command: dbt test --select stg_crm__cust_info

    WARNING:
    - Materialization is set to 'table'. dbt will recreate 'silver.stg_crm__cust_info' on each run.
*/

WITH source AS (
    SELECT * FROM {{ source('bronze_crm', 'crm_cust_info') }}
),
deduplicated AS (
    SELECT
        *
        ,ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS creation_order
    FROM
        source
    WHERE
        cst_id IS NOT NULL
),
cleaned AS (
    SELECT
        cst_id
        ,cst_key
        ,TRIM(cst_firstname)                    AS cst_firstname
        ,TRIM(cst_lastname)                     AS cst_lastname
        ,CASE UPPER(TRIM(cst_marital_status))
            WHEN 'S' THEN 'Single'
            WHEN 'M' THEN 'Married'
            ELSE 'n/a'
        END                                     AS cst_marital_status
        ,CASE UPPER(TRIM(cst_gndr))
            WHEN 'F' THEN 'Female'
            WHEN 'M' THEN 'Male'
            ELSE 'n/a'
        END                                     AS cst_gndr
        ,cst_create_date
        ,GETDATE() AS dwh_create_date
    FROM
        deduplicated
    WHERE
        creation_order = 1
)
SELECT * FROM cleaned