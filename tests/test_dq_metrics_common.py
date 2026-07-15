# tests/test_dq_metrics_common.py

import sys
import os
import pandas as pd
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts', 'data_quality'))

from dq_metrics_common import (
    infer_schema_layer,
    extract_test_nodes,
    parse_dbt_artifacts,
    attach_evaluated_rows,
    load_dq_metrics,
)

# ── Fixtures ─────────────────────────────────────────────────────────────────

MOCK_MANIFEST = {
    "metadata": {"invocation_id": "inv-001"},
    "nodes": {
        "model.dwh_dbt_files.stg_crm__cust_info": {
            "resource_type": "model",
            "name": "stg_crm__cust_info",
        },
        "test.dwh_dbt_files.not_null_cst_id": {
            "resource_type": "test",
            "test_metadata": {"name": "not_null"},
            "column_name": "cst_id",
            "config": {"severity": "error"},
            "depends_on": {"nodes": ["model.dwh_dbt_files.stg_crm__cust_info"]},
        },
        "test.dwh_dbt_files.unique_cst_id": {
            "resource_type": "test",
            "test_metadata": {"name": "unique"},
            "column_name": "cst_id",
            "config": {"severity": "error"},
            "depends_on": {"nodes": ["model.dwh_dbt_files.stg_crm__cust_info"]},
        },
        "test.dwh_dbt_files.some_unmapped_test": {
            "resource_type": "test",
            "test_metadata": {"name": "dbt_utils.expression_is_true"},
            "column_name": "cst_id",
            "config": {"severity": "error"},
            "depends_on": {"nodes": ["model.dwh_dbt_files.stg_crm__cust_info"]},
        },
    },
}

MOCK_RUN_RESULTS = {
    "results": [
        {"unique_id": "model.dwh_dbt_files.stg_crm__cust_info", "status": "success"},  # model, not a test
        {"unique_id": "test.dwh_dbt_files.not_null_cst_id", "status": "pass", "failures": 0},
        {"unique_id": "test.dwh_dbt_files.unique_cst_id", "status": "fail", "failures": 3},
        {"unique_id": "test.dwh_dbt_files.some_unmapped_test", "status": "pass", "failures": 0},
    ],
}


# ── infer_schema_layer ───────────────────────────────────────────────────────

def test_infer_schema_layer_staging():
    assert infer_schema_layer("stg_crm__cust_info") == "staging"

def test_infer_schema_layer_marts():
    assert infer_schema_layer("dim_customers") == "marts"

def test_infer_schema_layer_handles_none():
    assert infer_schema_layer(None) == "marts"


# ── extract_test_nodes ───────────────────────────────────────────────────────

def test_extract_test_nodes_filters_only_tests():
    result = extract_test_nodes(MOCK_MANIFEST)

    assert "test.dwh_dbt_files.not_null_cst_id" in result
    assert "model.dwh_dbt_files.stg_crm__cust_info" not in result
    assert len(result) == 3


# ── parse_dbt_artifacts ──────────────────────────────────────────────────────

def test_parse_maps_not_null_to_completeness():
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results=MOCK_RUN_RESULTS,
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="schedule",
    )

    row = df[df["test_name"] == "not_null"].iloc[0]
    assert row["test_category"] == "completeness"
    assert row["failure_count"] == 0
    assert row["model_name"] == "stg_crm__cust_info"

def test_parse_maps_unique_to_uniqueness():
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results=MOCK_RUN_RESULTS,
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="schedule",
    )

    row = df[df["test_name"] == "unique"].iloc[0]
    assert row["test_category"] == "uniqueness"
    assert row["failure_count"] == 3
    assert row["status"] == "fail"

def test_parse_skips_unmapped_test():
    """dbt_utils.expression_is_true is not in TEST_CATEGORY_MAP -- must be excluded."""
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results=MOCK_RUN_RESULTS,
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="schedule",
    )

    assert "dbt_utils.expression_is_true" not in df["test_name"].values

def test_parse_skips_non_test_nodes():
    """A model's own run_results entry must not appear as a DQ test row."""
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results=MOCK_RUN_RESULTS,
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="schedule",
    )

    assert len(df) == 2  # Only not_null and unique -- the two mapped tests.

def test_parse_marks_backfilled_rows():
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results=MOCK_RUN_RESULTS,
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="backfill",
        is_backfilled=True,
    )

    assert df["is_backfilled"].all()

def test_parse_empty_run_results_returns_empty_dataframe():
    df = parse_dbt_artifacts(
        manifest=MOCK_MANIFEST, run_results={"results": []},
        run_id="run-1", run_started_at="2026-07-15T03:00:00Z",
        run_finished_at="2026-07-15T03:01:00Z", trigger_type="schedule",
    )

    assert df.empty


# ── attach_evaluated_rows ────────────────────────────────────────────────────

def test_attach_evaluated_rows_queries_once_per_distinct_model():
    df = pd.DataFrame([
        {"model_name": "stg_crm__cust_info", "schema_layer": "staging"},
        {"model_name": "stg_crm__cust_info", "schema_layer": "staging"},  # duplicate model
    ])
    client = MagicMock()
    client.query.return_value.to_dataframe.return_value = pd.DataFrame({"row_count": [100]})

    result = attach_evaluated_rows(df, client=client, project_id="test-project")

    assert client.query.call_count == 1  # One model -> one query, despite 2 rows.
    assert (result["evaluated_rows"] == 100).all()

def test_attach_evaluated_rows_uses_correct_dataset_per_layer():
    df = pd.DataFrame([{"model_name": "dim_customers", "schema_layer": "marts"}])
    client = MagicMock()
    client.query.return_value.to_dataframe.return_value = pd.DataFrame({"row_count": [50]})

    attach_evaluated_rows(df, client=client, project_id="test-project")

    called_query = client.query.call_args[0][0]
    assert "test-project.gold.dim_customers" in called_query

def test_attach_evaluated_rows_handles_empty_dataframe():
    client = MagicMock()
    result = attach_evaluated_rows(pd.DataFrame(), client=client, project_id="test-project")

    assert result.empty
    client.query.assert_not_called()


# ── load_dq_metrics ──────────────────────────────────────────────────────────

def test_load_dq_metrics_uses_write_append():
    """Critical: this table must never use WRITE_TRUNCATE."""
    df = pd.DataFrame([{"run_id": "run-1", "test_name": "not_null"}])
    client = MagicMock()
    client.load_table_from_dataframe.return_value = MagicMock()

    load_dq_metrics(df, client=client, table_ref="test-project.dq.dq_test_log")

    _, kwargs = client.load_table_from_dataframe.call_args
    assert kwargs["job_config"].write_disposition == "WRITE_APPEND"

def test_load_dq_metrics_skips_empty_dataframe():
    client = MagicMock()

    load_dq_metrics(pd.DataFrame(), client=client, table_ref="test-project.dq.dq_test_log")

    client.load_table_from_dataframe.assert_not_called()

def test_load_dq_metrics_awaits_job_result():
    df = pd.DataFrame([{"run_id": "run-1", "test_name": "not_null"}])
    client = MagicMock()
    job = MagicMock()
    client.load_table_from_dataframe.return_value = job

    load_dq_metrics(df, client=client, table_ref="test-project.dq.dq_test_log")

    job.result.assert_called_once()