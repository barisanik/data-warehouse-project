"""
DAG: dwh_pipeline
Purpose: Orchestrates the full data warehouse pipeline using DockerOperator.
         Runs on manual trigger only.

Task order: ingestion → dbt_run → dbt_test
"""

from airflow import DAG
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount
from datetime import datetime
import os


# Network name: Docker Compose names it as <project_folder>_default
DOCKER_NETWORK = "data-warehouse-project_default"

# Shared environment variables passed to each container
PIPELINE_ENV = {
    "SA_USERNAME":       os.environ.get("SA_USERNAME"),
    "SA_PASSWORD":       os.environ.get("SA_PASSWORD"),
    "SERVER_NAME":       os.environ.get("SERVER_NAME"),
    "DATABASE_NAME":     os.environ.get("DATABASE_NAME"),
    "DRIVER_NAME":       os.environ.get("DRIVER_NAME"),
    "CORRUPTION_RATE":   os.environ.get("CORRUPTION_RATE"),
}


with DAG(
    dag_id="dwh_pipeline",
    start_date=datetime(2024, 1, 1),
    schedule=None,       # Manual trigger only
    catchup=False,
    tags=["dwh", "pipeline"],
) as dag:

    # ── Task 1: Ingestion ──────────────────────────────────
    # Pulls DummyJSON API data and loads it into Bronze tables.
    ingestion = DockerOperator(
        task_id="ingestion",
        image="data-warehouse-project-ingestion",
        network_mode=DOCKER_NETWORK,
        environment=PIPELINE_ENV,
        auto_remove="success",
        docker_url="unix://var/run/docker.sock",
        mount_tmp_dir=False,   # docker-in-docker mode
    )

    # ── Task 2: dbt run ────────────────────────────────────
    # Transforms Bronze → Silver → Gold with dbt models.
    dbt_run = DockerOperator(
        task_id="dbt_run",
        image="data-warehouse-project-dbt",
        command='bash -c "dbt deps --profiles-dir /dbt && dbt run --profiles-dir /dbt"',
        network_mode=DOCKER_NETWORK,
        environment=PIPELINE_ENV,
        auto_remove="success",
        docker_url="unix://var/run/docker.sock",
        mount_tmp_dir=False,
    )

    # ── Task 3: dbt test ───────────────────────────────────
    # Runs all schema and custom tests against Silver and Gold layers.
    dbt_test = DockerOperator(
        task_id="dbt_test",
        image="data-warehouse-project-dbt",
        command="dbt test --profiles-dir /dbt",    
        network_mode=DOCKER_NETWORK,
        environment=PIPELINE_ENV,
        auto_remove="success",
        docker_url="unix://var/run/docker.sock",
        mount_tmp_dir=False,
    )

    # ── Dependency chain ───────────────────────────────────
    ingestion >> dbt_run >> dbt_test