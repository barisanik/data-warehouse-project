"""
    SCRIPT: Parses the just-completed dbt Cloud run's manifest.json and run_results.json and appends recognized DQ test results into dq.dq_test_log.
    Script Purpose: Feeds Data Quality Dashboard Metrics.

    Run Command: python load_dq_metrics.py   (run from scripts/data_quality/, see ci.yml)

    Expects (env vars, set by ci.yml):
    - GCP_PROJECT_ID
    - DBT_RUN_ID
    - DBT_RUN_STARTED_AT
    - DBT_RUN_FINISHED_AT
    - GITHUB_EVENT_NAME
    
    Expects (files, downloaded by ci.yml into the working directory):
    - manifest.json
    - run_results.json
"""

import os
import json
import logging
from google.cloud import bigquery
from dotenv import load_dotenv

from dq_metrics_common import parse_dbt_artifacts, attach_evaluated_rows, load_dq_metrics

load_dotenv()

PROJECT_ID   = os.environ.get("GCP_PROJECT_ID")
DQ_TABLE_REF = f"{PROJECT_ID}.dq.dq_test_log"

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")


def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def main() -> None:
    logging.info("Starting DQ metrics load.")

    try:
        with open("manifest.json") as f:
            manifest = json.load(f)
        with open("run_results.json") as f:
            run_results = json.load(f)

        df = parse_dbt_artifacts(
            manifest=manifest,
            run_results=run_results,
            run_id=os.environ["DBT_RUN_ID"],
            run_started_at=os.environ["DBT_RUN_STARTED_AT"],
            run_finished_at=os.environ["DBT_RUN_FINISHED_AT"],
            trigger_type=os.environ.get("GITHUB_EVENT_NAME", "unknown"),
            is_backfilled=False,
        )

        client = get_client()
        df = attach_evaluated_rows(df, client=client, project_id=PROJECT_ID)
        load_dq_metrics(df, client=client, table_ref=DQ_TABLE_REF)
    except Exception as e:
        logging.critical(f"DQ metrics load failed: {e}")
        raise


if __name__ == "__main__":
    main()