-- Create View: Data Quality Metrics Summary
-- Purpose: Summarizes data quality metrics for dashboards.
-- Warning: Replace GCP_PROJECT_ID with your actual Google Cloud Project ID in the query before executing it.

CREATE OR REPLACE VIEW `GCP_PROJECT_ID.dq.dq_metrics_summary` AS
SELECT
    run_id,
    run_finished_at,
    trigger_type,
    is_backfilled,
    schema_layer,
    model_name,
    test_category,
    severity,
    SUM(failure_count)                                    AS total_failures,
    MAX(evaluated_rows)                                   AS evaluated_rows,
    SAFE_DIVIDE(SUM(failure_count), MAX(evaluated_rows))  AS failure_rate,
    1 - SAFE_DIVIDE(SUM(failure_count), MAX(evaluated_rows)) AS pass_rate
FROM `GCP_PROJECT_ID.dq.dq_test_log`
GROUP BY run_id, run_finished_at, trigger_type, is_backfilled, schema_layer, model_name, test_category, severity