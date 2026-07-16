# tests/test_get_data.py

import sys
import os
from datetime import datetime
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts', 'bronze'))

from unittest.mock import patch, MagicMock
from get_data import (
    extract,
    extract_with_ground_truth,
    load,
    build_record_key,
    build_ground_truth_rows,
    PRODUCT_CONFIG,
)

MOCK_API_RESPONSE = {
    'products': [
        {
            'id': 1,
            'title': 'Test Product',
            'category': 'test-category',
            'sku': 'ABC-123',
            'meta': {'createdAt': '2024-01-01'}
        }
    ]
}

def test_extract_returns_list():
    with patch('get_data.requests.get') as mock_get:
        mock_get.return_value.raise_for_status.return_value = None
        mock_get.return_value.json.return_value = MOCK_API_RESPONSE

        result = extract(PRODUCT_CONFIG, rate=0.0)  # rate=0.0 → corruption yok

        assert isinstance(result, list)
        assert len(result) > 0
        assert isinstance(result[0], dict)

def test_load_calls_bq_client():
    client = MagicMock()

    # Simulate job.result() returning successfully
    mock_job = MagicMock()
    client.load_table_from_dataframe.return_value = mock_job

    records = [
        {
            'id': 1,
            'title': 'Test Product',
            'category': 'test-category',
            'pkey': 'ABC-123',
            'createdAt': '2024-01-01',
        }
    ]

    load(PRODUCT_CONFIG, records, client)

    client.load_table_from_dataframe.assert_called_once()
    mock_job.result.assert_called_once()  # Ensures job completion is awaited


# ── Function: build_record_key ──────────────────────────────────────────────

def test_build_record_key_product():
    row = {"id": 1, "title": "Test"}
    assert build_record_key("product", row) == "1"

def test_build_record_key_user():
    row = {"id": 7, "first_name": "Jane"}
    assert build_record_key("user", row) == "7"

def test_build_record_key_order_combines_id_and_prd_id():
    """One cart (order) can yield multiple rows, one per product -- the key
    must disambiguate them."""
    row = {"id": 5, "prd_id": 12, "cust_id": 3}
    assert build_record_key("order", row) == "5_12"


# ── Function: build_ground_truth_rows ───────────────────────────────────────

FIXED_TIMESTAMP = datetime(2026, 7, 15, 10, 0, 0)

def test_ground_truth_detects_corrupted_field():
    original = {"id": 1, "title": "Test Product"}
    corrupted = {"id": 1, "title": "TEST PRODUCT"}  # title corrupted, id not

    rows = build_ground_truth_rows("product", original, corrupted, FIXED_TIMESTAMP)
    by_field = {r["field_name"]: r for r in rows}

    assert by_field["title"]["is_corrupted"] is True
    assert by_field["id"]["is_corrupted"] is False

def test_ground_truth_skips_fields_not_in_row():
    """User rows have no 'pkey' or 'title' -- these must not appear in output."""
    original = {"id": 1, "first_name": "Jane"}
    corrupted = {"id": 1, "first_name": "JANE"}

    rows = build_ground_truth_rows("user", original, corrupted, FIXED_TIMESTAMP)
    fields = {r["field_name"] for r in rows}

    assert "pkey" not in fields
    assert "title" not in fields
    assert fields == {"id", "first_name"}

def test_ground_truth_record_id_uses_original_not_corrupted_value():
    """Even if 'id' itself gets corrupted, record_id must reflect the clean
    (pre-corruption) value, so it stays joinable with the original source."""
    original = {"id": 42, "title": "Test"}
    corrupted = {"id": "dummy-42", "title": "Test"}  # id corrupted, title not

    rows = build_ground_truth_rows("product", original, corrupted, FIXED_TIMESTAMP)

    assert all(r["record_id"] == "42" for r in rows)

def test_ground_truth_leave_as_is_strategy_shows_not_corrupted():
    """corrupt_id's 'leave as-is' branch can produce a value identical to the
    original -- is_corrupted must be False in that case, even though the
    field was a corruption candidate that got selected."""
    original = {"id": 7, "title": "Test"}
    corrupted = {"id": "7", "title": "Test"}  # str(7) == "7", no visible change

    rows = build_ground_truth_rows("product", original, corrupted, FIXED_TIMESTAMP)
    id_row = next(r for r in rows if r["field_name"] == "id")

    assert id_row["is_corrupted"] is False

def test_ground_truth_order_uses_composite_key():
    original = {"id": 5, "prd_id": 12, "cust_id": 3, "total_price": 100}
    corrupted = {"id": 5, "prd_id": 12, "cust_id": 3, "total_price": 150}

    rows = build_ground_truth_rows("order", original, corrupted, FIXED_TIMESTAMP)

    assert all(r["record_id"] == "5_12" for r in rows)

def test_ground_truth_includes_run_timestamp():
    original = {"id": 1, "title": "Test"}
    corrupted = {"id": 1, "title": "TEST"}

    rows = build_ground_truth_rows("product", original, corrupted, FIXED_TIMESTAMP)

    assert all(r["ingestion_run_at"] == FIXED_TIMESTAMP for r in rows)

def test_ground_truth_corruption_type_matches_field():
    original = {"id": 1, "pkey": "ABC-123"}
    corrupted = {"id": 1, "pkey": "abc-123"}

    rows = build_ground_truth_rows("product", original, corrupted, FIXED_TIMESTAMP)
    by_field = {r["field_name"]: r for r in rows}

    assert by_field["id"]["corruption_type"] == "id"
    assert by_field["pkey"]["corruption_type"] == "key"


# ── Function: extract_with_ground_truth ─────────────────────────────────────

def test_extract_with_ground_truth_returns_both_lists():
    with patch('get_data.requests.get') as mock_get:
        mock_get.return_value.raise_for_status.return_value = None
        mock_get.return_value.json.return_value = MOCK_API_RESPONSE

        records, ground_truth_rows = extract_with_ground_truth(
            PRODUCT_CONFIG, rate=0.0, run_timestamp=FIXED_TIMESTAMP
        )

        assert isinstance(records, list)
        assert isinstance(ground_truth_rows, list)
        assert len(records) == 1
        # 4 corruption-candidate fields exist for product rows: id, title, category, pkey.
        # (createdAt is not a corruption candidate -- not in FIELD_CORRUPTION_TYPE.)
        assert len(ground_truth_rows) == 4

def test_extract_with_ground_truth_rate_zero_means_nothing_corrupted():
    with patch('get_data.requests.get') as mock_get:
        mock_get.return_value.raise_for_status.return_value = None
        mock_get.return_value.json.return_value = MOCK_API_RESPONSE

        _, ground_truth_rows = extract_with_ground_truth(
            PRODUCT_CONFIG, rate=0.0, run_timestamp=FIXED_TIMESTAMP
        )

        assert all(row["is_corrupted"] is False for row in ground_truth_rows)

def test_extract_with_ground_truth_record_count_matches_extract():
    """extract_with_ground_truth's processed_records must stay identical in
    shape/count to plain extract()'s output -- ground truth is additive,
    it must not change the bronze-bound record list."""
    with patch('get_data.requests.get') as mock_get:
        mock_get.return_value.raise_for_status.return_value = None
        mock_get.return_value.json.return_value = MOCK_API_RESPONSE

        plain_records = extract(PRODUCT_CONFIG, rate=0.0)
        records, _ = extract_with_ground_truth(
            PRODUCT_CONFIG, rate=0.0, run_timestamp=FIXED_TIMESTAMP
        )

        assert len(plain_records) == len(records)