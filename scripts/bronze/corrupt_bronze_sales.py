import pandas as pd
import os
from sqlalchemy import create_engine, text
import logging
import random
from datetime import datetime
import urllib.parse

### Initial parameters ###
# Seed
random.seed(0)

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

SEASON_RANGES = {
    'Winter' : (14, 30),
    'Spring' : (7, 14),
    'Summer' : (5, 11),
    'Autumn' : (10, 21)
}

SEASONS = {
        1: 'Winter',
        2: 'Spring',
        3: 'Summer',
        4: 'Autumn'
}

# Logging parameters
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),                    
        logging.FileHandler("corrupt_sales_details.log", encoding="utf-8")  
    ]
)

def get_engine(connection_string: str):
    params = urllib.parse.quote_plus(connection_string)
    engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
    return engine

def corrupt_order_date(order_date: pd.Timestamp,
                       month: int, 
                       season: str, 
                       season_ranges: dict[str, tuple[int, int]]
                       ) -> pd.Timestamp:
    total_delay = 0
    shipment_day_diff = 0
    bonus_delay = 0
    max_limit_divider = 2

    if season in ["Winter", "Spring", "Summer", "Autumn"]:
        shipment_day_diff = random.randint(season_ranges[season][0], season_ranges[season][1])

        if season == "Winter":
            max_limit_divider = 4
        elif season == "Autumn":
            max_limit_divider = 3

    else:
        logging.error(f"Error on function: corrupt_order_date. Invalid season: {season}")
        raise ValueError(f"Invalid season: {season}")
    
    if month in [1, 4, 7, 10]:
        is_outlier = random.choices([True, False], weights=[0.05, 0.95])[0]
        if is_outlier:
            outlier_type = random.choices(["same_day_shipment", "abnormal_late_shipment"], weights=[0.7, 0.3])[0]
            if outlier_type == "same_day_shipment":
                shipment_day_diff = 0
                bonus_delay = 0
            else:
                bonus_delay = random.randint(1, (season_ranges[season][1] // max_limit_divider))

    total_delay = shipment_day_diff + bonus_delay
    
    return order_date + pd.DateOffset(days=total_delay)

# --- Main ---
def main() -> None:
    script_start_time = datetime.now()
    logging.info(f"Script started at {script_start_time}.")
    
    try:
        # Set connection with localhost db.
        conn = get_engine(connection_string=CONNECTION_STRING)
        sql = "SELECT sls_ord_num, sls_order_dt FROM bronze.crm_sales_details WHERE sls_order_dt > 0"
        
        # Get bronze.crm_sales_details table.
        df = pd.read_sql_query(sql,conn)

        # Convert sls_order_dt from int to datetime.
        df['sls_order_dt'] = (pd.to_datetime(df['sls_order_dt'], format="%Y%m%d", errors="coerce"))
        logging.info(f"Ingested {len(df)} lines of record.")

        # Drops rows will NULL value.
        df = df.dropna()
        logging.info(f"Dropped n/a records. {len(df)} lines of record left.")

        # Extracts month and season of order dates.
        df['month'] = pd.DatetimeIndex(df['sls_order_dt']).month
        df['season'] = (df['sls_order_dt'].dt.month%12 + 3) // 3
        logging.info(f"Months and seasons have extracted from order dates.")

        df['season_name'] = df['season'].map(SEASONS)

        # Corrupts order dates and transformed datetime format with "YYYYMMDD".
        df['corrupted_ship_dt'] = df.apply(
                lambda row: 
                corrupt_order_date(
                    order_date=row['sls_order_dt'],
                    month=row['month'],
                    season=row['season_name'],
                    season_ranges=SEASON_RANGES
                ), axis=1)

        df['corrupted_ship_dt'] = df['corrupted_ship_dt'].dt.strftime("%Y%m%d")
        logging.info(f"Corruption has been completed.")

        # Loads dataframe to bronze.temp_crm_sales_details.
        df.to_sql("temp_crm_sales_details", conn, schema="bronze", if_exists="replace")
        logging.info(f"Temp table temp_crm_sales_details has been created.")

        # Update sls_ship_dt of [bronze].[crm_sales_details].
        sql = """
            UPDATE
                crm
            SET
                crm.sls_ship_dt = temp.corrupted_ship_dt
            FROM
                [bronze].[crm_sales_details] crm
                JOIN [bronze].[temp_crm_sales_details] temp ON crm.sls_ord_num = temp.sls_ord_num
            WHERE
                crm.sls_ord_num IS NOT NULL
                AND temp.sls_ord_num IS NOT NULL
        """

        with conn.connect() as connection:
            connection.execute(text(sql))
            connection.commit()

        logging.info(f"Updated table [bronze].[crm_sales_details].")

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise
    finally:
        script_end_time = datetime.now()
        logging.info(f"Script ended at {script_end_time}. Execution duration: {script_end_time - script_start_time}")


if __name__ == "__main__":
    main()