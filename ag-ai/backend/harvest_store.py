"""Persistent storage for farmer pre-harvest and post-harvest records.

Records are written to CSV files in farmer_submissions/ and can be
re-ingested for model retraining.
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

PRE_HARVEST_DIR = Path('farmer_submissions') / 'pre_harvest'
POST_HARVEST_DIR = Path('farmer_submissions') / 'post_harvest'

PRE_HARVEST_DIR.mkdir(parents=True, exist_ok=True)
POST_HARVEST_DIR.mkdir(parents=True, exist_ok=True)


def _timestamp() -> str:
    return datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')


def _date_folder() -> str:
    return datetime.now(timezone.utc).strftime('%Y-%m-%d')


def save_pre_harvest(record: dict) -> str:
    """Save a pre-harvest prediction record. Returns the file path."""
    dest = PRE_HARVEST_DIR / _date_folder()
    dest.mkdir(parents=True, exist_ok=True)
    farmer_id = str(record.get('farmer_id', 'unknown')).replace(' ', '_')
    fname = f'pre_{farmer_id}_{_timestamp()}.json'
    fpath = dest / fname
    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(record, f, ensure_ascii=False, indent=2, default=str)
    return str(fpath)


def save_post_harvest(record: dict) -> str:
    """Save a post-harvest actual record. Returns the file path."""
    dest = POST_HARVEST_DIR / _date_folder()
    dest.mkdir(parents=True, exist_ok=True)
    farmer_id = str(record.get('farmer_id', 'unknown')).replace(' ', '_')
    fname = f'post_{farmer_id}_{_timestamp()}.json'
    fpath = dest / fname
    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(record, f, ensure_ascii=False, indent=2, default=str)

    # Also append to a cumulative CSV for easy model retraining
    csv_path = POST_HARVEST_DIR / 'all_post_harvest.csv'
    row = {
        'farmer_id': record.get('farmer_id'),
        'crop': record.get('crop'),
        'region': record.get('region'),
        'district': record.get('district', ''),
        'year': record.get('year'),
        'area_hectares': record.get('area_hectares'),
        'actual_yield_kg': record.get('actual_yield_kg'),
        'actual_yield_kg_per_ha': (
            record['actual_yield_kg'] / record['area_hectares']
            if record.get('actual_yield_kg') and record.get('area_hectares')
            else None
        ),
        'actual_production_tonnes': record.get('actual_production_tonnes'),
        'harvest_date': record.get('harvest_date'),
        'quality_score': record.get('quality_score'),
        'recorded_at': _timestamp(),
    }
    df_new = pd.DataFrame([row])
    if csv_path.exists():
        df_existing = pd.read_csv(csv_path)
        df_combined = pd.concat([df_existing, df_new], ignore_index=True)
    else:
        df_combined = df_new
    df_combined.to_csv(csv_path, index=False)
    return str(fpath)


def load_post_harvest_actuals(
    crop: str = None,
    region: str = None,
    district: str = None,
    year: int = None,
) -> list:
    """Load post-harvest actuals for buyer queries."""
    csv_path = POST_HARVEST_DIR / 'all_post_harvest.csv'
    if not csv_path.exists():
        return []

    df = pd.read_csv(csv_path)

    if crop:
        df = df[df['crop'].str.upper() == crop.upper()]
    if region:
        df = df[df['region'].str.upper().str.contains(region.upper(), na=False)]
    if district:
        df = df[df['district'].str.upper().str.contains(district.upper(), na=False)]
    if year:
        df = df[df['year'] == int(year)]

    return df.where(pd.notna(df), None).to_dict('records')
