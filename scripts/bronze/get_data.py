"""
    SCRIPT: This script fetches product data from the dummyjson API, randomly corrupts clean data and insert into bronze layer.
    Script Purpose: To simulate real-world data quality issues and get data from multiple sources.
"""

import requests
import random
from datetime import datetime
import pyodbc
import logging
from dataclasses import dataclass

@dataclass
class IngestConfig:
    url: str
    data_type: str
    main_tag: str
    table: str
    insert_query: str
    extract_values: callable  # dict -> tuple

PRODUCT_CONFIG = IngestConfig(
    url="https://dummyjson.com/products?limit=10000",
    data_type="product",
    main_tag="products",
    table="bronze.djapi_product",
    insert_query="INSERT INTO bronze.djapi_product (id, title, category, pkey, createdAt) VALUES (?, ?, ?, ?, ?)",
    extract_values=lambda r: (r['id'], r['title'], r['category'], r['sku'], r['productCreatedAt'])
)

USER_CONFIG = IngestConfig(url="https://dummyjson.com/users?limit=10000",
    data_type="user",
    main_tag="users",
    table="bronze.djapi_customer",
    insert_query="INSERT INTO bronze.djapi_customer (id, first_name, last_name, gender, birthdate, city) VALUES (?, ?, ?, ?, ?, ?)",
    extract_values=lambda r: (r['id'], r['first_name'], r['last_name'], r['gender'], r['birthdate'], r['city'])
)

ORDER_CONFIG = IngestConfig(
    url="https://dummyjson.com/carts?limit=10000",
    data_type="order",
    main_tag="carts",
    table="bronze.djapi_order",
    insert_query="INSERT INTO bronze.djapi_order (id, prd_id, cust_id, unit_price, quantity, total_price) VALUES (?, ?, ?, ?, ?, ?)",
    extract_values=lambda r: (r['order_id'], r['cust_id'], r['prd_id'], r['unit_price'], r['quantity'], r['total_price'])
)

### Initial parameters ###
# Data corruption parameters
CORRUPTION_RATE = 0.4
random.seed(0)

# Database connection parameters
SERVER_NAME = 'localhost'
DATABASE_NAME = 'DataWarehouse'
DRIVER_NAME = "ODBC Driver 18 for SQL Server"
CONNECTION_STRING = f"""
    DRIVER={DRIVER_NAME};
    SERVER={SERVER_NAME};
    DATABASE={DATABASE_NAME};
    Trusted_Connection=yes;
    TrustServerCertificate=yes;
"""

# Logging parameters
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),                        # terminale yaz
        logging.FileHandler("ingest.log", encoding="utf-8")  # dosyaya da yaz
    ]
)

# Defined functions
def ingest(config: IngestConfig, cursor, rate: float):
    '''Fetches records from the API, clears the target table, and inserts corrupted data.'''

    try:
        records = fetch_data(config.url, config.main_tag)  
    except requests.RequestException as e:
        logging.error(f"API fetch failed for {config.table}: {e}")
        raise

    cursor.execute(f"DELETE FROM {config.table}")
    logging.info(f"DB: Records for {config.table} has been deleted.")
    
    try:
        for record in records:
            flat = flatten_data(config.data_type, record)

            rows = flat if isinstance(flat, list) else [flat] # If flat not in list nest it in a list.

            for row in rows:
                corrupted = corrupt_record(row, rate)
                cursor.execute(config.insert_query, config.extract_values(corrupted))

    except pyodbc.Error as e:
        logging.error(f"DB insert failed for {config.table}: {e}")
        raise

    logging.info(f"DB: Insert for {config.table} is successful.")

def get_connection():
    return pyodbc.connect(CONNECTION_STRING)

def fetch_data(url: str, maintag: str) -> list[dict]: 
    response = requests.get(url)
    response.raise_for_status()
    result = response.json()
    return result[maintag]

def flatten_data(datatype: str, data: dict) -> dict: 
    "Gets the relevant fields and flattens the structure for easier processing."
    if datatype == 'product':
        return {
            'id':        data['id'],
            'title':     data['title'],
            'category':  data['category'],
            'sku':       data['sku'],
            'productCreatedAt': data['meta']['createdAt'],
            'source':    'api-dummyjson',  
        }
    elif datatype == 'user':
        return {
            'id':        data['id'],
            'first_name':     data['firstName'],
            'last_name':  data['lastName'],
            'gender':       data['gender'],
            'birthdate': data['birthDate'],
            'city': data['address']['city'],
            'source':    'api-dummyjson',  
        }
    elif datatype == 'order':
        result = []
        for product in data['products']:
            result.append({
                'order_id':     data['id'],
                'cust_id':      data['userId'],
                'prd_id':       product['id'],
                'unit_price':   product['price'],
                'quantity':     product['quantity'],
                'total_price':  product['total'],
                'source':       'api-dummyjson',
            })
        return result
    else:
        logging.error(f"Error on function: flatten_data. Invalid data type: {datatype}")
        raise ValueError(f"Invalid data type: {datatype}")

def corrupt_id(value: int) -> str:
    "Corrupts numeric ID field by adding prefixes, leading zeros or adding whitespace."
    strategies = [ 
        lambda v: f"dummy-{v}",             # prefix -> dummy-1
        lambda v: f"{v:04d}",               # leading zeros -> "0001"
        lambda v: f" {v} ",                 # whitespace -> ' 1 '
        lambda v: str(v),                   # leave as it is (with less probability)
    ] 
    return random.choice(strategies)(value)

def corrupt_string(value: str) -> str:
    "Corrupts string fields by changing case and adding whitespace."
    strategies = [
        lambda v: v.upper(),
        lambda v: v.lower(),
        lambda v: (' ' * random.randint(1, 4)) + v,
        lambda v: v + (' ' * random.randint(1, 4)),
        lambda v: None,                     # NULL injection (rare chance)
    ]
    weights = [0.24, 0.24, 0.24, 0.24, 0.04]
    
    chosen = random.choices(strategies, weights=weights)[0]
    return chosen(value)

def corrupt_key(value: str) -> str:
    "Corrupts product key (sku) by changing delimiters, case and adding random suffixes."
    strategies = [
        lambda v: v.replace('-', '_'),              # BEA_ESS_001
        lambda v: v.lower(),                        # bea-ess-001
        lambda v: v + f"-{random.randint(10,99)}",  # add suffix
    ]
    return random.choice(strategies)(value)

def corrupt_price(value: float) -> float:
    "Corrupts unit price or total price of products."
    strategies = [
        lambda v: v,
        lambda v: v + ((v / 2) * -1),
        lambda v: v + (v / 2),
        lambda v: v + (v * 2),
        lambda v: None,
    ]
    weights = [0.7, 0.13, 0.13, 0.02, 0.02]
    resultValue = random.choices(strategies, weights=weights)[0](value)
    return resultValue

# Match fields with relevant corruption functions.
CORRUPTORS = {
    'id':        corrupt_id,
    'title':     corrupt_string,
    'category':  corrupt_string,
    'sku':       corrupt_key,
    'first_name':corrupt_string,
    'last_name': corrupt_string,
    'gender': corrupt_string,
    'order_id' : corrupt_id,
    'cust_id' : corrupt_id,
    'prd_id' : corrupt_id,
    'total_price' : corrupt_price
}

def corruption_possibility(field: str, value, rate: float):
    '''Decides whether to corrupt a field and returns the original or corrupted value.'''
    if field not in CORRUPTORS:
        return value
    if not random.choices([True, False], weights=[rate, 1 - rate])[0]:
        return value
    return CORRUPTORS[field](value)

def corrupt_record(record: dict, rate: float) -> dict:
    return {k: corruption_possibility(k, v, rate) for k, v in record.items()}

# --- Main ---
def main():
    script_start_time = datetime.now()
    logging.info(f"Script started at {script_start_time}.")

    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                logging.info("DB connection established.")
                for config in [PRODUCT_CONFIG, USER_CONFIG, ORDER_CONFIG]:
                    ingest(config, cursor, CORRUPTION_RATE)
                conn.commit()

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise

    finally:
        script_end_time = datetime.now()
        logging.info(f"Script ended at {script_end_time}. Execution duration: {script_end_time - script_start_time}")

if __name__ == "__main__":
    main()