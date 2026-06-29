"""
    SCRIPT: This script reads source CSV files and loads them into the bronze layer on BigQuery.
    Script Purpose: Replaces proc_load_bronze.sql BULK INSERT logic for BigQuery compatibility.
"""

import os
import pandas as pd
from datetime import datetime
from dataclasses import dataclass
from google.cloud import bigquery
import logging
from dotenv import load_dotenv

load_dotenv()

### Initial parameters ###
PROJECT_ID   = os.environ.get("GCP_PROJECT_ID")
DATASETS_DIR = os.environ.get("DATASETS_DIR", "datasets")  # Root folder of source CSV files.

# Logging parameters
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("load_bronze.log", encoding="utf-8"),
    ],
)


@dataclass
class LoadConfig:
    file_path: str   # Relative path under DATASETS_DIR.
    table: str       # Target BigQuery table in the format 'dataset.table'.
    bq_schema: list


# All bronze columns are STRING. Type casting happens in the silver layer.
CRM_CUST_INFO_CONFIG = LoadConfig(
    file_path="source_crm/cust_info.csv",
    table="bronze.crm_cust_info",
    bq_schema=[
        bigquery.SchemaField("cst_id",             "STRING"),
        bigquery.SchemaField("cst_key",            "STRING"),
        bigquery.SchemaField("cst_firstname",      "STRING"),
        bigquery.SchemaField("cst_lastname",       "STRING"),
        bigquery.SchemaField("cst_marital_status", "STRING"),
        bigquery.SchemaField("cst_gndr",           "STRING"),
        bigquery.SchemaField("cst_create_date",    "STRING"),
    ],
)

CRM_PRD_INFO_CONFIG = LoadConfig(
    file_path="source_crm/prd_info.csv",
    table="bronze.crm_prd_info",
    bq_schema=[
        bigquery.SchemaField("prd_id",       "STRING"),
        bigquery.SchemaField("prd_key",      "STRING"),
        bigquery.SchemaField("prd_nm",       "STRING"),
        bigquery.SchemaField("prd_cost",     "STRING"),
        bigquery.SchemaField("prd_line",     "STRING"),
        bigquery.SchemaField("prd_start_dt", "STRING"),
        bigquery.SchemaField("prd_end_dt",   "STRING"),
    ],
)

CRM_SALES_DETAILS_CONFIG = LoadConfig(
    file_path="source_crm/sales_details.csv",
    table="bronze.crm_sales_details",
    bq_schema=[
        bigquery.SchemaField("sls_ord_num",  "STRING"),
        bigquery.SchemaField("sls_prd_key",  "STRING"),
        bigquery.SchemaField("sls_cust_id",  "STRING"),
        bigquery.SchemaField("sls_order_dt", "STRING"),
        bigquery.SchemaField("sls_ship_dt",  "STRING"),
        bigquery.SchemaField("sls_due_dt",   "STRING"),
        bigquery.SchemaField("sls_sales",    "STRING"),
        bigquery.SchemaField("sls_quantity", "STRING"),
        bigquery.SchemaField("sls_price",    "STRING"),
    ],
)

ERP_CUST_AZ12_CONFIG = LoadConfig(
    file_path="source_erp/cust_az12.csv",
    table="bronze.erp_cust_az12",
    bq_schema=[
        bigquery.SchemaField("cid",   "STRING"),
        bigquery.SchemaField("bdate", "STRING"),
        bigquery.SchemaField("gen",   "STRING"),
    ],
)

ERP_LOC_A101_CONFIG = LoadConfig(
    file_path="source_erp/loc_a101.csv",
    table="bronze.erp_loc_a101",
    bq_schema=[
        bigquery.SchemaField("cid",   "STRING"),
        bigquery.SchemaField("cntry", "STRING"),
    ],
)

ERP_PX_CAT_G1V2_CONFIG = LoadConfig(
    file_path="source_erp/px_cat_g1v2.csv",
    table="bronze.erp_px_cat_g1v2",
    bq_schema=[
        bigquery.SchemaField("id",          "STRING"),
        bigquery.SchemaField("cat",         "STRING"),
        bigquery.SchemaField("subcat",      "STRING"),
        bigquery.SchemaField("maintenance", "STRING"),
    ],
)


def get_client() -> bigquery.Client:
    # Reads GOOGLE_APPLICATION_CREDENTIALS from environment automatically.
    return bigquery.Client(project=PROJECT_ID)


def extract(config: LoadConfig) -> pd.DataFrame:
    '''Reads a source CSV file into a DataFrame.'''
    file_path = os.path.join(DATASETS_DIR, config.file_path)

    df = pd.read_csv(file_path, dtype=str)  # dtype=str keeps all values as string, prevents pandas from inferring types.
    df.columns = df.columns.str.lower()     # ERP CSV headers are uppercase. Normalize them to lowercase.

    logging.info(f"Read {len(df)} rows from {file_path}.")
    return df


def load(config: LoadConfig, df: pd.DataFrame, client: bigquery.Client) -> None:
    '''Clears the target table and loads the DataFrame.'''
    table_ref = f"{PROJECT_ID}.{config.table}"

    # Replace None/NaN with None so BQ stores them as NULL rather than the string 'nan'.
    df = df.where(df.notna(), other=None)

    job_config = bigquery.LoadJobConfig(
        schema=config.bq_schema,
        write_disposition="WRITE_TRUNCATE",
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()

    logging.info(f"BQ: {len(df)} rows loaded into {table_ref}.")


# --- Main ---
def main() -> None:
    script_start_time = datetime.now()
    logging.info(f"Script started at {script_start_time}.")

    configs = [
        CRM_CUST_INFO_CONFIG,
        CRM_PRD_INFO_CONFIG,
        CRM_SALES_DETAILS_CONFIG,
        ERP_CUST_AZ12_CONFIG,
        ERP_LOC_A101_CONFIG,
        ERP_PX_CAT_G1V2_CONFIG,
    ]

    try:
        client = get_client()
        logging.info("BigQuery client initialized.")

        for config in configs:
            df = extract(config=config)
            load(config=config, df=df, client=client)

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise

    finally:
        script_end_time = datetime.now()
        logging.info(f"Script ended at {script_end_time}. Execution duration: {script_end_time - script_start_time}")


if __name__ == "__main__":
    main()