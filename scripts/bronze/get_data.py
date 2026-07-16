"""
    SCRIPT: This script fetches data from the dummyjson API, randomly corrupts clean data and loads it into the bronze layer.
    Script Purpose: To simulate real-world data quality issues and get data from multiple sources.
"""

import os
import requests
import random
import pandas as pd
from datetime import datetime
from dataclasses import dataclass
from google.cloud import bigquery
import logging
from dotenv import load_dotenv

load_dotenv()

@dataclass
class IngestConfig:
    url: str
    data_type: str
    main_tag: str
    table: str
    bq_schema: list     # BigQuery dataset schema details


PRODUCT_CONFIG = IngestConfig(
    url="https://dummyjson.com/products?limit=10000",
    data_type="product",
    main_tag="products",
    table="bronze.djapi_product",
    bq_schema=[
        bigquery.SchemaField("id",        "STRING"),
        bigquery.SchemaField("title",     "STRING"),
        bigquery.SchemaField("category",  "STRING"),
        bigquery.SchemaField("pkey",      "STRING"),
        bigquery.SchemaField("createdAt", "STRING"),
    ],
)

USER_CONFIG = IngestConfig(
    url="https://dummyjson.com/users?limit=10000",
    data_type="user",
    main_tag="users",
    table="bronze.djapi_customer",
    bq_schema=[
        bigquery.SchemaField("id",         "STRING"),
        bigquery.SchemaField("first_name", "STRING"),
        bigquery.SchemaField("last_name",  "STRING"),
        bigquery.SchemaField("gender",     "STRING"),
        bigquery.SchemaField("birthdate",  "STRING"),
        bigquery.SchemaField("city",       "STRING"),
        bigquery.SchemaField("state",      "STRING"),
        bigquery.SchemaField("state_code", "STRING"),
        bigquery.SchemaField("country",    "STRING"),
    ],
)

ORDER_CONFIG = IngestConfig(
    url="https://dummyjson.com/carts?limit=10000",
    data_type="order",
    main_tag="carts",
    table="bronze.djapi_order",
    bq_schema=[
        bigquery.SchemaField("id",          "STRING"),
        bigquery.SchemaField("prd_id",      "STRING"),
        bigquery.SchemaField("cust_id",     "STRING"),
        bigquery.SchemaField("unit_price",  "STRING"),
        bigquery.SchemaField("quantity",    "STRING"),
        bigquery.SchemaField("total_price", "STRING"),
    ],
)

# Ground truth table: Stores the pre-corruption state of each corruption-candidate for data quality dashboard.
GROUND_TRUTH_CONFIG = IngestConfig(
    url="",
    data_type="ground_truth",
    main_tag="",
    table="dq.dq_ground_truth",
    # All columns STRING, matching the bronze convention
    bq_schema=[
        bigquery.SchemaField("data_type",        "STRING"),
        bigquery.SchemaField("record_id",        "STRING"),
        bigquery.SchemaField("field_name",       "STRING"),
        bigquery.SchemaField("corruption_type",  "STRING"),
        bigquery.SchemaField("is_corrupted",     "STRING"),
        bigquery.SchemaField("ingestion_run_at", "STRING"),
    ],
)


### Initial parameters ###
# Data corruption parameters
CORRUPTION_RATE = 0.4
random.seed(0)

# BigQuery connection parameters
PROJECT_ID = os.environ.get("GCP_PROJECT_ID") # Gets project id from service account json file under keys/ folder.

# Logging parameters
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),                                # enables visibility on console
        logging.FileHandler("ingest.log", encoding="utf-8"),    # enables recording on a file
    ],
)


def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def extract(config: IngestConfig, rate: float) -> list[dict]:
    """Fetches records from the API and corrupts them."""
    try:
        processed_records = []
        records = fetch_data(config.url, config.main_tag)

        for record in records:
            flat = flatten_data(config.data_type, record)
            rows = flat if isinstance(flat, list) else [flat]  # If flat not in list, nest it in a list.

            for row in rows:
                corrupted = corrupt_record(row, rate)
                processed_records.append(corrupted)

        return processed_records

    except requests.RequestException as e:
        logging.error(f"API fetch failed for {config.table}: {e}")
        raise


def extract_with_ground_truth(config: IngestConfig, rate: float, run_timestamp: datetime) -> tuple[list[dict], list[dict]]:
    """Same as extract(), but additionally builds ground-truth rows by diffing each record against its pre-corruption state.

    Kept as a separate function from extract() on purpose: This function only observes corrupt_record()'s output (a value-level
    diff), it does not consume random numbers itself, so the existing corruption sequence is not affected by adding ground truth.
    """
    try:
        processed_records = []
        ground_truth_rows = []
        records = fetch_data(config.url, config.main_tag)

        for record in records:
            flat = flatten_data(config.data_type, record)
            rows = flat if isinstance(flat, list) else [flat]

            for row in rows:
                corrupted = corrupt_record(row, rate)
                processed_records.append(corrupted)
                ground_truth_rows.extend(
                    build_ground_truth_rows(config.data_type, row, corrupted, run_timestamp)
                )

        return processed_records, ground_truth_rows

    except requests.RequestException as e:
        logging.error(f"API fetch failed for {config.table}: {e}")
        raise


def load(config: IngestConfig, records: list[dict], client: bigquery.Client) -> None:
    """Converts corrupted Dummy Json API data to a DataFrame and insert it into BigQuery."""
    try:
        table_ref = f"{PROJECT_ID}.{config.table}"
        df = pd.DataFrame(records)
        df = df.astype(str).where(df.notna(), other=None)

        job_config = bigquery.LoadJobConfig(
            schema=config.bq_schema,
            write_disposition="WRITE_TRUNCATE",     # Delete and insert
        )

        job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()

        logging.info(f"BQ: {len(records)} records loaded into {table_ref}.")

    except Exception as e:
        logging.error(f"BQ load failed for {config.table}: {e}")
        raise

def fetch_data(url: str, maintag: str) -> list[dict]:
    response = requests.get(url)
    response.raise_for_status()
    result = response.json()
    return result[maintag]


def flatten_data(datatype: str, data: dict) -> dict:
    """Gets the relevant fields and flattens the structure for easier processing."""
    if datatype == "product":
        return {
            "id":        data["id"],
            "title":     data["title"],
            "category":  data["category"],
            "pkey":      data["sku"],
            "createdAt": data["meta"]["createdAt"],
        }
    elif datatype == "user":
        return {
            "id":           data["id"],
            "first_name":   data["firstName"],
            "last_name":    data["lastName"],
            "gender":       data["gender"],
            "birthdate":    data["birthDate"],
            "city":         data["address"]["city"],
            "state":        data["address"]["state"],
            "state_code":   data["address"]["stateCode"],
            "country":      data["address"]["country"],
        }
    elif datatype == "order":
        result = []
        for product in data["products"]:
            result.append({
                "id":          data["id"],
                "cust_id":     data["userId"],
                "prd_id":      product["id"],
                "unit_price":  product["price"],
                "quantity":    product["quantity"],
                "total_price": product["total"],
            })
        return result
    else:
        logging.error(f"Error on function: flatten_data. Invalid data type: {datatype}")
        raise ValueError(f"Invalid data type: {datatype}")


def corrupt_id(value: int) -> str:
    """Corrupts numeric ID field by adding prefixes, leading zeros or adding whitespace."""
    strategies = [
        lambda v: f"dummy-{v}",      # prefix    → dummy-1
        lambda v: f"{v:04d}",        # leading zeros → "0001"
        lambda v: f" {v} ",          # whitespace → ' 1 '
        lambda v: str(v),            # leave as-is (with less probability)
    ]
    return random.choice(strategies)(value)

def corrupt_string(value: str) -> str:
    """Corrupts string fields by changing case and adding whitespace."""
    strategies = [
        lambda v: v.upper(),
        lambda v: v.lower(),
        lambda v: (" " * random.randint(1, 4)) + v,
        lambda v: v + (" " * random.randint(1, 4)),
        lambda v: None,              # NULL injection (rare chance)
    ]
    weights = [0.24, 0.24, 0.24, 0.24, 0.04]

    chosen = random.choices(strategies, weights=weights)[0]
    return chosen(value)


def corrupt_key(value: str) -> str:
    """Corrupts product key by changing delimiters, case and adding random suffixes."""
    strategies = [
        lambda v: v.replace("-", "_"),              # BEA_ESS_001
        lambda v: v.lower(),                        # bea-ess-001
        lambda v: v + f"-{random.randint(10, 99)}", # add suffix
    ]
    return random.choice(strategies)(value)

def corrupt_price(value: float) -> float:
    """Corrupts unit price or total price of products."""
    strategies = [
        lambda v: v,
        lambda v: v + ((v / 2) * -1),
        lambda v: v + (v / 2),
        lambda v: v + (v * 2),
        lambda v: None,
    ]
    weights = [0.7, 0.13, 0.13, 0.02, 0.02]
    return random.choices(strategies, weights=weights)[0](value)


# Match fields with relevant corruption functions.
CORRUPTORS = {
    "id":          corrupt_id,
    "title":       corrupt_string,
    "category":    corrupt_string,
    "pkey":        corrupt_key,
    "first_name":  corrupt_string,
    "last_name":   corrupt_string,
    "gender":      corrupt_string,
    "cust_id":     corrupt_id,
    "prd_id":      corrupt_id,
    "total_price": corrupt_price,
}

# Maps each corruption-candidate field to its corruption category for data quality dashboard.
FIELD_CORRUPTION_TYPE = {
    "id":          "id",
    "cust_id":     "id",
    "prd_id":      "id",
    "title":       "string",
    "category":    "string",
    "first_name":  "string",
    "last_name":   "string",
    "gender":      "string",
    "pkey":        "key",
    "total_price": "price",
}


def corruption_possibility(field: str, value, rate: float):
    """Decides whether to corrupt a field and returns the original or corrupted value."""
    if field not in CORRUPTORS:
        return value
    if not random.choices([True, False], weights=[rate, 1 - rate])[0]:
        return value
    return CORRUPTORS[field](value)


def corrupt_record(record: dict, rate: float) -> dict:
    return {k: corruption_possibility(k, v, rate) for k, v in record.items()}


def build_record_key(data_type: str, original_row: dict) -> str:
    """Builds a stable identifier from PRE-corruption values.
    Orders need id + prd_id since one order (cart) can yield multiple rows,
    one per product in the cart.
    """
    if data_type == "order":
        return f"{original_row['id']}_{original_row['prd_id']}"
    return str(original_row["id"])


def build_ground_truth_rows(data_type: str, original_row: dict, corrupted_row: dict, run_timestamp: datetime) -> list[dict]:
    """Compares a clean row against its corrupted counterpart and produces one ground-truth row per corruption-candidate field present in the row."""
    record_key = build_record_key(data_type, original_row)
    rows = []

    for field, corruption_type in FIELD_CORRUPTION_TYPE.items():
        if field not in original_row:
            continue  # Field doesn't apply to this data_type.

        original_value = str(original_row[field])
        corrupted_value = str(corrupted_row[field])

        rows.append({
            "data_type":        data_type,
            "record_id":        record_key,
            "field_name":       field,
            "corruption_type":  corruption_type,
            "is_corrupted":     original_value != corrupted_value,
            "ingestion_run_at": run_timestamp,
        })

    return rows


# --- Main ---
def main():
    script_start_time = datetime.now()
    logging.info(f"Script started at {script_start_time}.")

    try:
        client = get_client()
        logging.info("BigQuery client initialized.")

        all_ground_truth_rows = []

        for config in [PRODUCT_CONFIG, USER_CONFIG, ORDER_CONFIG]:
            records, ground_truth_rows = extract_with_ground_truth(
                config=config, rate=CORRUPTION_RATE, run_timestamp=script_start_time
            )
            load(config=config, records=records, client=client)
            all_ground_truth_rows.extend(ground_truth_rows)

        load(config=GROUND_TRUTH_CONFIG, records=all_ground_truth_rows, client=client)

    except Exception as e:
        logging.critical(f"Script failed: {e}")
        raise

    finally:
        script_end_time = datetime.now()
        logging.info(f"Script ended at {script_end_time}. Execution duration: {script_end_time - script_start_time}")


if __name__ == "__main__":
    main()