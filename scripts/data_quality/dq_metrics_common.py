"""
    SCRIPT: Shared parsing/loading logic for dbt Cloud Data Quality (DQ) metrics.
    Script Purpose: Parses dbt's manifest.json + run_results.json artifacts into a flat
    DQ metric record set and appends them into BigQuery (dq.dq_test_log).

    Used by both:
    - load_dq_metrics.py     (nightly CI run, one invocation at a time)
    - backfill_dq_metrics.py (one-time historical backfill, many invocations)

"""

import logging
import pandas as pd
from google.cloud import bigquery

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

# Maps raw dbt test names to their DQ category, used for dashboard grouping.
# Tests not listed here are intentionally skipped (out of scope).
TEST_CATEGORY_MAP = {
    "not_null":                                 "completeness",
    "unique":                                    "uniqueness",
    "accepted_values":                           "validity",
    "dbt_utils.accepted_range":                  "validity",
    "matches_pattern":                           "validity",
    "assert_case":                               "validity",
    "no_whitespace":                              "validity",
    "assert_length":                              "validity",
    "not_contains_string":                        "validity",
    "relationships":                              "referential_integrity",
    "dbt_utils.unique_combination_of_columns":    "referential_integrity",
    "assert_formula":                             "accuracy",
    "assert_less_than":                           "accuracy",
}

DQ_TABLE_SCHEMA = [
    bigquery.SchemaField("run_id",           "STRING"),
    bigquery.SchemaField("invocation_id",    "STRING"),
    bigquery.SchemaField("run_started_at",   "TIMESTAMP"),
    bigquery.SchemaField("run_finished_at",  "TIMESTAMP"),
    bigquery.SchemaField("trigger_type",     "STRING"),
    bigquery.SchemaField("model_name",       "STRING"),
    bigquery.SchemaField("schema_layer",     "STRING"),
    bigquery.SchemaField("column_name",      "STRING"),
    bigquery.SchemaField("test_name",        "STRING"),
    bigquery.SchemaField("test_category",    "STRING"),
    bigquery.SchemaField("severity",         "STRING"),
    bigquery.SchemaField("status",           "STRING"),
    bigquery.SchemaField("failure_count",    "INT64"),
    bigquery.SchemaField("evaluated_rows",   "INT64"),
    bigquery.SchemaField("unique_id",        "STRING"),
    bigquery.SchemaField("is_backfilled",    "BOOL"),   # True for historically-backfilled rows.
]


def infer_schema_layer(model_name: str) -> str:
    """Derives 'staging' vs 'marts' from the project's stg_<src>__<entity> naming convention."""
    if model_name and model_name.startswith("stg_"):
        return "staging"
    return "marts"


def extract_test_nodes(manifest: dict) -> dict:
    """Returns {unique_id: node} for every node in manifest.json that is a dbt test."""
    return {
        uid: node for uid, node in manifest.get("nodes", {}).items()
        if node.get("resource_type") == "test"
    }


def parse_dbt_artifacts(
    manifest: dict,
    run_results: dict,
    run_id: str,
    run_started_at: str,
    run_finished_at: str,
    trigger_type: str,
    is_backfilled: bool = False,
) -> pd.DataFrame:
    """Parses manifest.json + run_results.json into one row per recognized DQ test."""
    test_nodes = extract_test_nodes(manifest)
    invocation_id = manifest.get("metadata", {}).get("invocation_id")

    rows = []
    for result in run_results.get("results", []):
        unique_id = result.get("unique_id")
        node = test_nodes.get(unique_id)
        if node is None:
            continue  # Not a test node (e.g. a model run in the same invocation).

        test_name = node.get("test_metadata", {}).get("name")
        if test_name not in TEST_CATEGORY_MAP:
            continue  # Unmapped test type (out of scope)

        depends_on = node.get("depends_on", {}).get("nodes", [])
        model_unique_id = depends_on[0] if depends_on else None
        model_name = manifest.get("nodes", {}).get(model_unique_id, {}).get("name")

        rows.append({
            "run_id":          run_id,
            "invocation_id":   invocation_id,
            "run_started_at":  run_started_at,
            "run_finished_at": run_finished_at,
            "trigger_type":    trigger_type,
            "model_name":      model_name,
            "schema_layer":    infer_schema_layer(model_name),
            "column_name":     node.get("column_name"),
            "test_name":       test_name,
            "test_category":   TEST_CATEGORY_MAP[test_name],
            "severity":        node.get("config", {}).get("severity"),
            "status":          result.get("status"),
            "failure_count":   result.get("failures"),
            "evaluated_rows":  None,
            "unique_id":       unique_id,
            "is_backfilled":   is_backfilled,
        })

    return pd.DataFrame(rows)


def compute_model_row_counts(models: list, client: bigquery.Client, project_id: str) -> dict:
    """Runs one COUNT(*) per (model_name, schema_layer) pair and returns {model_name: row_count}."""
    counts = {}
    for model_name, schema_layer in models:
        if model_name is None:
            continue
        dataset = "silver" if schema_layer == "staging" else "gold"
        query = f"SELECT COUNT(*) AS row_count FROM `{project_id}.{dataset}.{model_name}`"
        result = client.query(query).to_dataframe()
        counts[model_name] = int(result["row_count"].iloc[0])
        logging.info(f"Counted {counts[model_name]} rows in {dataset}.{model_name}.")
    return counts


def attach_evaluated_rows(df: pd.DataFrame, client: bigquery.Client, project_id: str) -> pd.DataFrame:
    """Fills evaluated_rows with one COUNT(*) per distinct model referenced in df.

    Intended for single-run callers (e.g. the nightly load_dq_metrics.py), where
    querying once per model per invocation is already minimal. Callers processing
    multiple runs against the same models should use compute_model_row_counts()
    directly with a cache instead -- see backfill_dq_metrics.py.
    """
    if df.empty:
        return df

    models = df[["model_name", "schema_layer"]].drop_duplicates().itertuples(index=False)
    counts = compute_model_row_counts(models, client=client, project_id=project_id)
    df["evaluated_rows"] = df["model_name"].map(counts)
    return df


def load_dq_metrics(df: pd.DataFrame, client: bigquery.Client, table_ref: str) -> None:
    """Appends parsed DQ metric rows to BigQuery."""
    if df.empty:
        logging.info("No recognized DQ test rows to load. Skipping.")
        return

    job_config = bigquery.LoadJobConfig(
        schema=DQ_TABLE_SCHEMA,
        write_disposition="WRITE_APPEND",
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="run_finished_at",
        ),
        clustering_fields=["model_name", "test_category"],
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    logging.info(f"Appended {len(df)} DQ metric rows into {table_ref}.")