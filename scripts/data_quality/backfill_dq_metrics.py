"""
    SCRIPT: One-time backfill of historical dbt Cloud runs into dq.dq_test_log.
    Script Purpose: Populates failure trend metric with real history instead of
    starting from zero, using dbt Cloud's retained run artifacts.

    Run Command: python backfill_dq_metrics.py

    Expects (env vars):
    - GCP_PROJECT_ID
    - DBT_ACCOUNT_ID
    - DBT_JOB_ID
    - DBT_API_TOKEN
    - DBT_ACCESS_URL

    WARNING:
    - Skips runs whose run_id is already present in dq_test_log, so re-running this script is safe and won't duplicate rows.
    - Only processes runs with status = success. failed/cancelled runs don't reliably have a complete run_results.json.
    - evaluated_rows for backfilled rows reflects TODAY's row counts, not the row counts at the time of that historical run (bronze/silver/gold are
      WRITE_TRUNCATE and don't keep historical snapshots). Rows are flagged is_backfilled=True.
"""

import os
import logging
import requests
from google.cloud import bigquery
from dotenv import load_dotenv

from dq_metrics_common import parse_dbt_artifacts, compute_model_row_counts, load_dq_metrics

load_dotenv()

PROJECT_ID     = os.environ.get("GCP_PROJECT_ID")
DBT_ACCOUNT_ID = os.environ.get("DBT_ACCOUNT_ID")
DBT_JOB_ID     = os.environ.get("DBT_JOB_ID")
DBT_API_TOKEN  = os.environ.get("DBT_API_TOKEN")
DBT_ACCESS_URL = os.environ.get("DBT_ACCESS_URL")
DQ_TABLE_REF   = f"{PROJECT_ID}.dq.dq_test_log"

HEADERS  = {"Authorization": f"Token {DBT_API_TOKEN}"}
BASE_URL = f"https://{DBT_ACCESS_URL}/api/v2/accounts/{DBT_ACCOUNT_ID}"

STATUS_SUCCESS = 10  # dbt Cloud Admin API run status code for a successful run.

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")


def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def get_existing_run_ids(client: bigquery.Client) -> set:
    """Returns run_ids already present in dq_test_log, to make this script re-run safe."""
    query = f"SELECT DISTINCT run_id FROM `{DQ_TABLE_REF}`"
    try:
        return set(client.query(query).to_dataframe()["run_id"])
    except Exception:
        logging.warning("dq_test_log not found yet or empty -- treating as no existing runs.")
        return set()


def list_successful_runs() -> list:
    """Lists this job's finished runs, most recent first (dbt Cloud retains the last 20)."""
    response = requests.get(
        f"{BASE_URL}/runs/",
        headers=HEADERS,
        params={"job_definition_id": DBT_JOB_ID, "order_by": "-finished_at", "limit": 20},
    )
    response.raise_for_status()
    runs = response.json()["data"]
    return [r for r in runs if r.get("status") == STATUS_SUCCESS]


def fetch_artifact(run_id: str, filename: str) -> dict:
    response = requests.get(f"{BASE_URL}/runs/{run_id}/artifacts/{filename}", headers=HEADERS)
    response.raise_for_status()
    return response.json()


def main() -> None:
    try:
        client = get_client()
        existing_run_ids = get_existing_run_ids(client)

        runs = list_successful_runs()
        logging.info(f"Found {len(runs)} successful runs. {len(existing_run_ids)} already loaded.")

        row_count_cache: dict = {}  # model_name -> row_count, reused across all runs in this backfill.

        for run in runs:
            run_id = str(run["id"])
            if run_id in existing_run_ids:
                logging.info(f"Run {run_id} already loaded. Skipping.")
                continue

            manifest = fetch_artifact(run_id, "manifest.json")
            run_results = fetch_artifact(run_id, "run_results.json")

            df = parse_dbt_artifacts(
                manifest=manifest,
                run_results=run_results,
                run_id=run_id,
                run_started_at=run["started_at"],
                run_finished_at=run["finished_at"],
                trigger_type="backfill",
                is_backfilled=True,
            )

            # Only COUNT(*) for models not already cached from a previous run in this backfill
            models_in_df = df[["model_name", "schema_layer"]].drop_duplicates().itertuples(index=False)
            uncached_models = [
                (model_name, schema_layer) for model_name, schema_layer in models_in_df
                if model_name is not None and model_name not in row_count_cache
            ]
            if uncached_models:
                row_count_cache.update(
                    compute_model_row_counts(uncached_models, client=client, project_id=PROJECT_ID)
                )

            df["evaluated_rows"] = df["model_name"].map(row_count_cache)
            load_dq_metrics(df, client=client, table_ref=DQ_TABLE_REF)

    except Exception as e:
        logging.critical(f"Backfill failed: {e}")
        raise


if __name__ == "__main__":
    main()