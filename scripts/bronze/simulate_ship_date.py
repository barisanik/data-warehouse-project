import pandas as pd
import os
from sqlalchemy import create_engine, text, Engine
import logging
import random
from datetime import datetime
import urllib.parse

### Initial parameters ###
# Database connection parameters
SERVER   = os.environ.get('SERVER_NAME', 'localhost')
DATABASE = os.environ.get('DATABASE_NAME', 'DataWarehouse')
DRIVER   = os.environ.get('DRIVER_NAME', 'ODBC Driver 18 for SQL Server')
USERNAME   = os.environ.get('SA_USERNAME')
PASSWORD   = os.environ.get('SA_PASSWORD')

CONNECTION_STRING = (
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    f"TrustServerCertificate=yes;"
)

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

def get_engine(connection_string: str):
    try:
        params = urllib.parse.quote_plus(connection_string)
        engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
        return engine
    except Exception as e:
        logging.error(f"Error on function: get_engine. Details: {e}")
        raise

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

def extract(conn: Engine) -> pd.DataFrame:
    '''Fetches records from the bronze.crm_sales_details.'''

    EXTRACT_SQL = "SELECT sls_ord_num, sls_order_dt FROM bronze.crm_sales_details WHERE sls_order_dt > 0"
    
    # Get bronze.crm_sales_details table.
    df = pd.read_sql_query(EXTRACT_SQL,conn)
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
    
def load(df: pd.DataFrame, conn: Engine):
    '''Update sls_ship_dt column values of bronze.crm_sales_details.'''

    # Loads dataframe to bronze.temp_crm_sales_details.
    df.to_sql("temp_crm_sales_details", conn, schema="bronze", if_exists="replace")
    logging.info(f"Temp table temp_crm_sales_details has been created.")

    # Update sls_ship_dt of [bronze].[crm_sales_details].
    UPDATE_SQL = """
        UPDATE
            crm
        SET
            crm.sls_ship_dt = temp.simulated_ship_dt
        FROM
            [bronze].[crm_sales_details] crm
            JOIN [bronze].[temp_crm_sales_details] temp ON crm.sls_ord_num = temp.sls_ord_num
        WHERE
            crm.sls_ord_num IS NOT NULL
            AND temp.sls_ord_num IS NOT NULL
    """

    with conn.connect() as connection:
        connection.execute(text(UPDATE_SQL))
        connection.commit()

    logging.info(f"Updated table [bronze].[crm_sales_details].")

# --- Main ---
def main() -> None:
    # Set seed to 0.
    random.seed(0)

    log_event(phase_name="Script", log_type="start")
    
    try:
        # Set connection with localhost db.
        conn = get_engine(connection_string=CONNECTION_STRING)

        log_event(phase_name="Extraction", log_type="start")
        df = extract(conn=conn)
        log_event(phase_name="Extraction", log_type="end")

        log_event(phase_name="Transform", log_type="start")
        df = transform(df=df, season_config=SEASON_CONFIG)
        log_event(phase_name="Transform", log_type="end")

        log_event(phase_name="Load", log_type="start")
        load(df=df, conn=conn)
        log_event(phase_name="Load", log_type="end")

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise
    finally:
        log_event(phase_name="Script", log_type="end")

if __name__ == "__main__":
    main()