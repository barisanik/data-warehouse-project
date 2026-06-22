# tests/test_simulate_ship_date.py

import sys
import os
import pytest
import pandas as pd
import datetime
from sqlalchemy import Engine

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts', 'bronze'))

from unittest.mock import patch, MagicMock
from simulate_ship_date import extract, transform, load, SEASON_CONFIG, simulate_ship_date, extract, transform, load

## Function test: simulate_ship_date (ssd)
# ssd - Happy path

def test_ssd_normal():
    result = simulate_ship_date(
        order_date=pd.Timestamp("2025-06-15"),
        month=6,
        season="Summer",
        season_config=SEASON_CONFIG
    )
    assert result > pd.Timestamp("2025-06-15")

def test_ssd_same_day_shipment():
    with patch("simulate_ship_date.random.choices") as mock_choices:
        mock_choices.side_effect = [
            [True],              # 1. is_outlier = True
            ["same_day_shipment"] # 2.outlier_type = "same_day_shipment"
        ]
        result = simulate_ship_date(
            order_date=pd.Timestamp("2025-04-03"),
            month=4,
            season="Spring",
            season_config=SEASON_CONFIG
        )
        assert result == pd.Timestamp("2025-04-03")

# ssd - Negative cases

def test_ssd_invalid_season():
    with pytest.raises(ValueError):
        simulate_ship_date(
            order_date=pd.Timestamp("2025-06-15"),
            month=6, 
            season="InvalidMonthParameter", 
            season_config=SEASON_CONFIG
        )

# ssd - Edge cases

def test_invalid_month():
    with pytest.raises(ValueError):
        simulate_ship_date(
            order_date=pd.Timestamp("2025-06-15"),
            month=13, 
            season="June", 
            season_config=SEASON_CONFIG
        )

# Function test: transform
## transform - Happy path

def test_normal_transform():
    df = pd.DataFrame({
        'sls_ord_num': ['SO001'],
        'sls_order_dt': [20250615]
    })

    result = transform(df=df, season_config=SEASON_CONFIG)
    
    assert 'simulated_ship_dt' in result.columns
    assert len(result['simulated_ship_dt'].iloc[0]) == 8
    assert (
        pd.to_datetime(result['simulated_ship_dt'], format="%Y%m%d") > result['sls_order_dt']
    ).all()

## transform - Negative cases

def test_dropna_function_transform():
    df = pd.DataFrame({
        'sls_ord_num': ['SO001', 'SO002'],
        'sls_order_dt': [20250615, None] 
    })

    result = transform(df=df, season_config=SEASON_CONFIG)

    assert len(result) == 1

# Function test: extract
## extract - Happy path

def test_extract():
    conn = MagicMock()

    with patch('simulate_ship_date.pd.read_sql_query') as mock_read:
        mock_read.return_value = pd.DataFrame({
            'sls_ord_num': ['SO001'],
            'sls_order_dt': [20250615]
        })
        result = extract(conn=conn)
                         
        assert isinstance(result, pd.DataFrame)
        assert len(result) > 0

# extract - Negative cases

def test_extract_raises_on_db_failure():
    with patch('simulate_ship_date.pd.read_sql_query') as mock_read:
        mock_read.side_effect = Exception("DB connection failed")
        with pytest.raises(Exception):
            extract(conn=MagicMock())