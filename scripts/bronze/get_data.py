"""
    SCRIPT: This script fetches product data from the dummyjson API, randomly corrupts clean data and insert into bronze layer.
    Script Purpose: To simulate real-world data quality issues and get data from multiple sources.
"""

import requests
import random
from datetime import datetime


CORRUPTION_RATE = 0.4
CORRUPTABLE_FIELDS = ['title', 'category']
API_URL = ""

def fetch_products(url: str) -> list:
    response = requests.get(url)
    response.raise_for_status()
    return response.json()['products']

def fetch_data(url: str, maintag: str, subtag: str = None) -> list:
    response = requests.get(url)
    response.raise_for_status()
    result = response.json()
    if subtag != None:
        return result[maintag][subtag]
    else:
        return result[maintag]

def flatten_data(datatype: str, json: dict) -> dict:
    "Gets the relevant fields and flattens the structure for easier processing."
    if datatype == 'product':
        return {
            'id':        json['id'],
            'title':     json['title'],
            'category':  json['category'],
            'sku':       json['sku'],
            'createdAt': json['meta']['createdAt'],
            'source':    'api-dummyjson',  
        }
    elif datatype == 'user':
        return {
            'id':        json['id'],
            'first_name':     json['firstName'],
            'last_name':  json['lastName'],
            'gender':       json['gender'],
            'birthdate': json['birthDate'],
            'city': json['address']['city'],
            'source':    'api-dummyjson',  
        }

def corrupt_id(value: int) -> str:
    "Corrupts numeric ID field by adding prefixes, leading zeros or adding whitespace."
    strategies = [
        lambda v: f"dummy-{v}",             # prefix -> dummy-1
        lambda v: f"{v:04d}",               # leading zeros -> "0001"
        lambda v: f" {v} ",                 # whitespace -> ' 1 '
        lambda v: str(v),                   # leave as it is (with less probability)
    ]
    return random.choice(strategies)(value)

def corrupt_string(value: str) -> str:
    "Corrupts string fields by changing case and adding whitespace."
    strategies = [
        lambda v: v.upper(),
        lambda v: v.lower(),
        lambda v: (' ' * random.randint(1, 4)) + v,
        lambda v: v + (' ' * random.randint(1, 4)),
        lambda v: None,                     # NULL injection
    ]
    weights = [0.2, 0.2, 0.2, 0.2, 0.05]
    
    chosen = random.choices(strategies, weights=weights)[0]
    return chosen(value)

def corrupt_key(value: str) -> str:
    "Corrupts product key (sku) by changing delimiters, case and adding random suffixes."
    strategies = [
        lambda v: v.replace('-', '_'),              # BEA_ESS_001
        lambda v: v.lower(),                        # bea-ess-001
        lambda v: v + f"-{random.randint(10,99)}",  # suffix
    ]
    return random.choice(strategies)(value)

def corrupt_date(value: str) -> str:
    """Change date format to simulate different sources."""
    try:
        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return value  
    strategies = [
        lambda d: d.strftime('%d/%m/%Y'),          
        lambda d: d.strftime('%m-%d-%Y'),        
        lambda d: d.strftime('%Y%m%d'),           
        lambda d: d.strftime('%d %b %Y'),          
        lambda d: str(int(d.timestamp())),         
        lambda d: d.strftime('%d/%m/%y %H:%M'),    
    ]
    return random.choice(strategies)(dt)

CORRUPTORS = {
    'id':        corrupt_id,
    'title':     corrupt_string,
    'category':  corrupt_string,
    'sku':       corrupt_key,
    'createdAt': corrupt_date,
    'first_name':corrupt_string,
    'last_name': corrupt_string,
    'gender': corrupt_string,
    'birthdate': corrupt_date,
}

def corruption_possibility(field: str, value, rate: float):
    "Probability check"
    if field not in CORRUPTORS:
        return value
    if not random.choices([True, False], weights=[rate, 1 - rate])[0]:
        return value
    return CORRUPTORS[field](value)

def corrupt_record(record: dict, rate: float) -> dict:
    return {k: corruption_possibility(k, v, rate) for k, v in record.items()}

# --- Main ---

def main():
    API_URL = "https://dummyjson.com/products?limit=10000"
    products = fetch_data(API_URL, 'products')
    for product in products:
        flatten_product = flatten_data('product', product)
        corrupted = corrupt_record(flatten_product, CORRUPTION_RATE)
        print(corrupted)
        print("-")
        
    print('USER DATA ---------')

    API_URL = "https://dummyjson.com/users?limit=10000"
    users = fetch_data(API_URL, 'users')
    for user in users:
        flatten_user_record = flatten_data('user', user)
        corrupted_record = corrupt_record(flatten_user_record, CORRUPTION_RATE)
        print(corrupted_record)
        print("-")

if __name__ == "__main__":
    main()

