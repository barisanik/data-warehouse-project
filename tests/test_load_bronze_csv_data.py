# tests/test_load_bronze.py

import sys
import os
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock, call

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts', 'bronze'))

from load_bronze_csv_data import extract, load, CRM_CUST_INFO_CONFIG, ERP_LOC_A101_CONFIG

MOCK_CSV_DATA = pd.DataFrame({
    'cst_id':             ['1', '2'],
    'cst_key':            ['AW00011000', 'AW00011001'],
    'cst_firstname':      ['John', 'Jane'],
    'cst_lastname':       ['Doe', 'Doe'],
    'cst_marital_status': ['S', 'M'],
    'cst_gndr':           ['M', 'F'],
    'cst_create_date':    ['2020-01-01', '2021-01-01'],
})


# ── Function: extract ──────────────────────────────────────────────────────────

# extract - Happy path

def test_extract_returns_dataframe():
    with patch('load_bronze_csv_data.pd.read_csv') as mock_read:
        mock_read.return_value = MOCK_CSV_DATA.copy()

        result = extract(CRM_CUST_INFO_CONFIG)

        assert isinstance(result, pd.DataFrame)
        assert len(result) == 2

def test_extract_reads_with_dtype_str():
    """Ensures all columns land as strings — type casting belongs in Silver."""
    with patch('load_bronze_csv_data.pd.read_csv') as mock_read:
        mock_read.return_value = MOCK_CSV_DATA.copy()

        extract(CRM_CUST_INFO_CONFIG)

        _, kwargs = mock_read.call_args
        assert kwargs.get('dtype') == str

def test_extract_lowercases_column_names():
    """ERP CSV headers are uppercase. extract() must normalise them."""
    mock_df = MOCK_CSV_DATA.copy()
    mock_df.columns = [c.upper() for c in mock_df.columns]

    with patch('load_bronze_csv_data.pd.read_csv') as mock_read:
        mock_read.return_value = mock_df

        result = extract(CRM_CUST_INFO_CONFIG)

        assert all(col == col.lower() for col in result.columns)

def test_extract_uses_correct_file_path():
    with patch('load_bronze_csv_data.pd.read_csv') as mock_read:
        mock_read.return_value = MOCK_CSV_DATA.copy()

        extract(CRM_CUST_INFO_CONFIG)

        actual_path = mock_read.call_args[0][0]
        assert CRM_CUST_INFO_CONFIG.file_path in actual_path

# extract - Negative cases

def test_extract_raises_on_missing_file():
    with patch('load_bronze_csv_data.pd.read_csv') as mock_read:
        mock_read.side_effect = FileNotFoundError("No such file or directory")

        with pytest.raises(FileNotFoundError):
            extract(CRM_CUST_INFO_CONFIG)


# ── Function: load ─────────────────────────────────────────────────────────────

# load - Happy path

def test_load_calls_bq_load_once():
    client = MagicMock()
    client.load_table_from_dataframe.return_value = MagicMock()

    load(CRM_CUST_INFO_CONFIG, MOCK_CSV_DATA.copy(), client)

    assert client.load_table_from_dataframe.call_count == 1

def test_load_awaits_job_result():
    """job.result() must be called so errors surface before the script exits."""
    client = MagicMock()
    job = MagicMock()
    client.load_table_from_dataframe.return_value = job

    load(CRM_CUST_INFO_CONFIG, MOCK_CSV_DATA.copy(), client)

    job.result.assert_called_once()

def test_load_uses_write_truncate():
    """Full load pattern: each run must replace the target table."""
    client = MagicMock()
    client.load_table_from_dataframe.return_value = MagicMock()

    load(CRM_CUST_INFO_CONFIG, MOCK_CSV_DATA.copy(), client)

    _, kwargs = client.load_table_from_dataframe.call_args
    job_config = kwargs['job_config']
    assert job_config.write_disposition == "WRITE_TRUNCATE"

def test_load_targets_correct_table():
    client = MagicMock()
    client.load_table_from_dataframe.return_value = MagicMock()

    load(ERP_LOC_A101_CONFIG, pd.DataFrame({'cid': ['1'], 'cntry': ['US']}), client)

    positional_args = client.load_table_from_dataframe.call_args[0]
    table_ref = positional_args[1]
    assert ERP_LOC_A101_CONFIG.table in table_ref

# load - Data quality

def test_load_replaces_nan_with_none():
    """NaN must become NULL in BigQuery, not the string 'nan'."""
    df_with_nan = MOCK_CSV_DATA.copy()
    df_with_nan.loc[0, 'cst_firstname'] = float('nan')

    client = MagicMock()
    client.load_table_from_dataframe.return_value = MagicMock()

    load(CRM_CUST_INFO_CONFIG, df_with_nan, client)

    passed_df = client.load_table_from_dataframe.call_args[0][0]
    assert pd.isna(passed_df['cst_firstname'].iloc[0])  # None veya NaN — ikisi de BQ'da NULL

# load - Negative cases

def test_load_raises_on_bq_error():
    client = MagicMock()
    client.load_table_from_dataframe.side_effect = Exception("BQ load failed")

    with pytest.raises(Exception, match="BQ load failed"):
        load(CRM_CUST_INFO_CONFIG, MOCK_CSV_DATA.copy(), client)

def test_load_raises_when_job_result_fails():
    """A failed BQ job that only surfaces on .result() must still propagate."""
    client = MagicMock()
    job = MagicMock()
    job.result.side_effect = Exception("Job failed on BQ side")
    client.load_table_from_dataframe.return_value = job

    with pytest.raises(Exception, match="Job failed on BQ side"):
        load(CRM_CUST_INFO_CONFIG, MOCK_CSV_DATA.copy(), client)