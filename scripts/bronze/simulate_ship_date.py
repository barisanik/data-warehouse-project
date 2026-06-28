import pandas as pd
import os
from google.cloud import bigquery
import logging
import random
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

### Initial parameters ###
# BigQuery connection parameters
PROJECT_ID = os.environ.get('GCP_PROJECT_ID')

SEASON_CONFIG = {
    1: { "name": "Winter", "ship_range": (14, 30), "cap_divisor": 4 },
    2: { "name": "Spring", "ship_range": (7, 14), "cap_divisor": 2 },
    3: { "name": "Summer", "ship_range": (5, 11), "cap_divisor": 2 },
    4: { "name": "Autumn", "ship_range": (10, 21), "cap_divisor": 3 }
}

OUTLIER_PROBABILITY    = [0.05, 0.95]
SAME_DAY_SHIP_WEIGHT   = [0.70, 0.30]
QUARTER_START_MONTHS   = [1, 4, 7, 10]

# Logging parameters
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),                    
        logging.FileHandler("simulate_ship_date.log", encoding="utf-8")  
    ]
)

def log_event(phase_name: str, log_type: str) -> None:
    timestamp = datetime.now()

    if log_type in ["start","end"]: 
        log_type += "ed"
    else: 
        raise ValueError(f"Invalid argument ({log_type}) on function log_event.")
    
    logging.info(f"{phase_name} phase {log_type} at {timestamp}")

def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)

def simulate_ship_date(order_date: pd.Timestamp,
                       month: int, 
                       season: str, 
                       season_config: dict
                       ) -> pd.Timestamp:
    total_delay = 0
    shipment_day_diff = 0
    bonus_delay = 0

    if not 1 <= month <= 12:
        logging.error(f"Error on function: simulate_ship_date. Invalid month: {month}")
        raise ValueError(f"Invalid month: {month}")

    if not season in [v["name"] for v in season_config.values()]:
        logging.error(f"Error on function: simulate_ship_date. Invalid season: {season}")
        raise ValueError(f"Invalid season: {season}")
    else:
        detected_season_details = next(v for v in season_config.values() if v["name"] == season)
        shipment_day_diff = random.randint(detected_season_details["ship_range"][0], detected_season_details["ship_range"][1])
        
    
    if month in QUARTER_START_MONTHS:
        is_outlier = random.choices([True, False], weights=OUTLIER_PROBABILITY)[0]
        if is_outlier:
            outlier_type = random.choices(["same_day_shipment", "abnormal_late_shipment"], weights=SAME_DAY_SHIP_WEIGHT)[0]
            if outlier_type == "same_day_shipment":
                shipment_day_diff = 0
                bonus_delay = 0
            else:
                bonus_delay = random.randint(1, detected_season_details["ship_range"][1] // detected_season_details["cap_divisor"])

    total_delay = shipment_day_diff + bonus_delay
    
    return order_date + pd.DateOffset(days=total_delay)

def extract(client: bigquery.Client) -> pd.DataFrame:
    '''Fetches records from the bronze.crm_sales_details.'''

    EXTRACT_SQL = f"""
        SELECT sls_ord_num, sls_order_dt
        FROM `{PROJECT_ID}.bronze.crm_sales_details`
        WHERE SAFE_CAST(sls_order_dt AS INT64) > 0
    """
    
    # Get bronze.crm_sales_details table.
    df = client.query(EXTRACT_SQL).to_dataframe()
    logging.info(f"Ingested {len(df)} lines of record.")
    return df

def transform(df: pd.DataFrame, season_config) -> pd.DataFrame:
    '''Simulates shipment dates.'''
    
    # Convert sls_order_dt from int to datetime.
    df['sls_order_dt'] = (pd.to_datetime(df['sls_order_dt'], format="%Y%m%d", errors="coerce"))

    # Drops rows will NULL value.
    df = df.dropna()
    logging.info(f"Dropped n/a records. {len(df)} lines of record left.")

    # Extracts month and season of order dates.
    df['month'] = pd.DatetimeIndex(df['sls_order_dt']).month
    df['season'] = (df['sls_order_dt'].dt.month%12 + 3) // 3
    logging.info(f"Months and seasons have extracted from order dates.")

    df['season_name'] = df['season'].map({k: v["name"] for k, v in season_config.items()})

    # Simulates ship dates and transform datetime format with "YYYYMMDD".
    df['simulated_ship_dt'] = df.apply(
            lambda row: 
            simulate_ship_date(
                order_date=row['sls_order_dt'],
                month=row['month'],
                season=row['season_name'],
                season_config=season_config
            ), axis=1)

    df['simulated_ship_dt'] = df['simulated_ship_dt'].dt.strftime("%Y%m%d")
    
    return df
    
def load(df: pd.DataFrame, client: bigquery.Client) -> None:
    '''Update sls_ship_dt column values of bronze.crm_sales_details.'''

    # Loads simulated dates to a temp table.
    temp_table_ref = f"{PROJECT_ID}.bronze.temp_crm_sales_details"
    job_config = bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE")
    job = client.load_table_from_dataframe(
        df[['sls_ord_num', 'simulated_ship_dt']], temp_table_ref, job_config=job_config
    )
    job.result()
    logging.info(f"Temp table temp_crm_sales_details has been created.")

    # Update sls_ship_dt of bronze.crm_sales_details via MERGE.
    # BigQuery does not support UPDATE with JOIN; MERGE is the equivalent pattern.
    MERGE_SQL = f"""
        MERGE `{PROJECT_ID}.bronze.crm_sales_details` AS crm
        USING `{PROJECT_ID}.bronze.temp_crm_sales_details` AS temp
        ON crm.sls_ord_num = temp.sls_ord_num
        WHEN MATCHED THEN
            UPDATE SET crm.sls_ship_dt = temp.simulated_ship_dt
    """

    client.query(MERGE_SQL).result()
    logging.info(f"Updated table bronze.crm_sales_details.")

# --- Main ---
def main() -> None:
    # Set seed to 0.
    random.seed(0)

    log_event(phase_name="Script", log_type="start")
    
    try:
        client = get_client()

        log_event(phase_name="Extraction", log_type="start")
        df = extract(client=client)
        log_event(phase_name="Extraction", log_type="end")

        log_event(phase_name="Transform", log_type="start")
        df = transform(df=df, season_config=SEASON_CONFIG)
        log_event(phase_name="Transform", log_type="end")

        log_event(phase_name="Load", log_type="start")
        load(df=df, client=client)
        log_event(phase_name="Load", log_type="end")

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise
    finally:
        log_event(phase_name="Script", log_type="end")

if __name__ == "__main__":
    main()