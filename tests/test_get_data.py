# tests/test_get_data.py

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts', 'bronze'))

from unittest.mock import patch, MagicMock
from get_data import extract, load, PRODUCT_CONFIG

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