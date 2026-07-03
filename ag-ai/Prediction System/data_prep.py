"""
Shared data loading and feature engineering for AgriGuard Prediction System.

Data sources:
  1. agri_guard_training_data_regional.csv        — historical crop yield baseline
  2. World Bank AG.CON.FERT.ZS   (Ghana)          — fertilizer kg/ha arable land (1960-2024)
  3. World Bank AG.LND.AGRI.K2   (Ghana)          — agricultural land sq. km (1960-2024)
  4. World Bank AG.PRD.CROP.XD   (Ghana)          — crop production index (1960-2024)
  5. Farmer harvest_submissions  (Supabase DB)     — real ground-truth yields
  6. Farm diary entries          (Supabase DB)     — in-season growing conditions

Features produced (7 core + up to 10 diary = 17 total):
  Core:
    Area_Planted_ha              — farm / plot size in hectares
    Year                         — harvest year (temporal trend)
    Crop_encoded                 — crop type (label-encoded)
    Region_encoded               — Ghana region (label-encoded)
    District_encoded             — district (label-encoded)
    national_fertilizer_kg_ha    — national fertilizer use kg/ha that year (World Bank)
    national_agri_land_km2       — national agricultural land km² (World Bank)

  Diary / in-season (added after continuous-learning retrains):
    avg_temp_max_c, avg_temp_min_c
    total_rainfall_mm, gdd
    fertilizer_kg_ha, fertilizer_applications
    pest_events, disease_events
    irrigation_days, quality_score

Target: Yield_kg_per_ha
"""

import os
import sys
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split

# ── Paths (relative to project root) ──────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent  # ag-ai/
DATASET_DIR  = PROJECT_ROOT / 'dataset'

REGIONAL_CSV   = DATASET_DIR / 'data' / 'historical' / 'agri_guard_merged_training_data.csv'
_REGIONAL_CSV_FALLBACK = DATASET_DIR / 'data' / 'historical' / 'agri_guard_training_data_regional.csv'
WB_FERT_CSV    = DATASET_DIR / 'API_AG.CON.FERT.ZS_DS2_en_csv_v2_393435' / 'API_AG.CON.FERT.ZS_DS2_en_csv_v2_393435.csv'
WB_LAND_CSV    = DATASET_DIR / 'API_AG.LND.AGRI.K2_DS2_en_csv_v2_350995' / 'API_AG.LND.AGRI.K2_DS2_en_csv_v2_350995.csv'
WB_CROP_CSV    = DATASET_DIR / 'API_AG.PRD.CROP.XD_DS2_en_csv_v2_404591' / 'API_AG.PRD.CROP.XD_DS2_en_csv_v2_404591.csv'

DIARY_FEATURES = [
    'avg_temp_max_c', 'avg_temp_min_c',
    'total_rainfall_mm', 'gdd',
    'fertilizer_kg_ha', 'fertilizer_applications',
    'pest_events', 'disease_events',
    'irrigation_days', 'quality_score',
]

# Fallback defaults when no diary data exists at all
DIARY_DEFAULTS = {
    'avg_temp_max_c': 31.0,  'avg_temp_min_c': 22.0,
    'total_rainfall_mm': 800.0, 'gdd': 1200.0,
    'fertilizer_kg_ha': 50.0, 'fertilizer_applications': 2.0,
    'pest_events': 0.0,  'disease_events': 0.0,
    'irrigation_days': 0.0, 'quality_score': 7.0,
}


# ── World Bank Ghana series ────────────────────────────────────────────────────

def _load_wb_series(csv_path: Path, country_code: str = 'GHA') -> dict:
    """
    Parse a World Bank wide-format CSV and return {year: value} for one country.
    Returns empty dict if file not found or country not present.
    """
    if not csv_path.exists():
        return {}
    try:
        df = pd.read_csv(csv_path, skiprows=4)
        row = df[df['Country Code'] == country_code]
        if row.empty:
            return {}
        row = row.iloc[0]
        result = {}
        for col in df.columns[4:]:  # year columns
            try:
                yr = int(col)
                val = row[col]
                if pd.notna(val) and str(val).strip() not in ('', 'nan'):
                    result[yr] = float(val)
            except (ValueError, TypeError):
                continue
        return result
    except Exception as e:
        print(f'  [WARN] Could not load {csv_path.name}: {e}')
        return {}


def load_world_bank_ghana() -> dict:
    """
    Load Ghana national agricultural indicators from World Bank datasets.
    Returns a dict: {year: {indicator_name: value, ...}}
    """
    fert  = _load_wb_series(WB_FERT_CSV)   # fertilizer kg/ha
    land  = _load_wb_series(WB_LAND_CSV)   # agricultural land km²
    crop  = _load_wb_series(WB_CROP_CSV)   # crop production index

    all_years = sorted(set(list(fert) + list(land) + list(crop)))
    wb = {}
    for yr in all_years:
        wb[yr] = {
            'national_fertilizer_kg_ha': fert.get(yr),
            'national_agri_land_km2':    land.get(yr),
            'national_crop_prod_index':  crop.get(yr),
        }
    return wb


def _fill_wb_series(wb: dict, key: str) -> dict:
    """
    Forward-fill then backward-fill missing years for a single WB indicator.
    Returns {year: value}.
    """
    years = sorted(wb.keys())
    filled = {}
    last  = None
    for yr in years:
        v = wb[yr].get(key)
        if v is not None:
            last = v
        if last is not None:
            filled[yr] = last
    # backward fill earliest years
    years_with = sorted(filled.keys())
    if years_with:
        first_val = filled[years_with[0]]
        for yr in years:
            if yr not in filled:
                filled[yr] = first_val
    return filled


# ── Historical CSV loader ──────────────────────────────────────────────────────

def load_historical() -> pd.DataFrame:
    """Load merged training CSV (falls back to regional CSV if merged not built yet)."""
    for path in [REGIONAL_CSV, _REGIONAL_CSV_FALLBACK,
                 PROJECT_ROOT / 'agri_guard_training_data_regional.csv']:
        if path.exists():
            df = pd.read_csv(path)
            print(f'  [DATA] Loaded {path.name} ({len(df)} rows)')
            return df
    print(f'  [WARN] No training CSV found')
    return pd.DataFrame()


# ── DB data loader ─────────────────────────────────────────────────────────────

def load_db_data():
    """Pull harvest submissions + diary from Supabase. Returns (harvest, diary)."""
    sys.path.insert(0, str(PROJECT_ROOT))
    sys.path.insert(0, str(PROJECT_ROOT / 'backend' / 'fastapi'))
    try:
        from dotenv import load_dotenv
        load_dotenv(PROJECT_ROOT / '.env')
    except ImportError:
        pass

    harvest_rows, diary_rows = [], []
    try:
        from backend.fastapi.db import query_all_for_training, admin_all_diary
    except Exception:
        try:
            from db import query_all_for_training, admin_all_diary
        except Exception as e:
            print(f'  [WARN] DB unavailable: {e}')
            return [], []

    try:
        harvest_rows = query_all_for_training()
    except Exception as e:
        print(f'  [WARN] query_all_for_training: {e}')
    try:
        diary_rows = admin_all_diary(include_hidden=True)
    except Exception as e:
        print(f'  [WARN] admin_all_diary: {e}')

    return harvest_rows, diary_rows


# ── Diary aggregation ──────────────────────────────────────────────────────────

def aggregate_diary(diary_rows) -> dict:
    """Aggregate diary per (farmer_id, crop, year) → feature dict."""
    buckets = {}
    for e in diary_rows:
        farmer_id = e.get('farmer_id')
        crop = (e.get('crop') or '').strip()
        rec_date = e.get('record_date')
        if not rec_date:
            continue
        year = rec_date.year if hasattr(rec_date, 'year') else int(str(rec_date)[:4])
        key = (farmer_id, crop, year)
        if key not in buckets:
            buckets[key] = dict(
                tmax=[], tmin=[], rain=0., gdd=0.,
                fert_kg=0., fert_n=0,
                pest=0, disease=0, irr=0, n=0,
            )
        b = buckets[key]
        tmax = _flt(e.get('temp_max_c'), 30.)
        tmin = _flt(e.get('temp_min_c'), 22.)
        if e.get('temp_max_c') is not None:
            b['tmax'].append(tmax)
        if e.get('temp_min_c') is not None:
            b['tmin'].append(tmin)
        b['rain'] += _flt(e.get('rainfall_mm'), 0.)
        b['gdd']  += max(0., (tmax + tmin) / 2 - 10.)
        if e.get('fertilizer_applied') and e.get('fertilizer_kg_ha'):
            b['fert_kg'] += _flt(e.get('fertilizer_kg_ha'), 0.)
            b['fert_n'] += 1
        if e.get('pest_observed'):
            b['pest'] += 1
        if e.get('disease_observed'):
            b['disease'] += 1
        if e.get('irrigation_applied'):
            b['irr'] += 1
        b['n'] += 1

    result = {}
    for key, b in buckets.items():
        result[key] = {
            'avg_temp_max_c':        float(np.mean(b['tmax'])) if b['tmax'] else None,
            'avg_temp_min_c':        float(np.mean(b['tmin'])) if b['tmin'] else None,
            'total_rainfall_mm':     b['rain'],
            'gdd':                   b['gdd'],
            'fertilizer_kg_ha':      b['fert_kg'],
            'fertilizer_applications': float(b['fert_n']),
            'pest_events':           float(b['pest']),
            'disease_events':        float(b['disease']),
            'irrigation_days':       float(b['irr']),
        }
    return result


# ── Combined dataset builder ───────────────────────────────────────────────────

def build_dataset(use_db: bool = True,
                  include_diary_features: bool = False) -> pd.DataFrame:
    """
    Combine all data sources into one training DataFrame.

    Args:
        use_db: Whether to pull farmer submissions and diary from DB.
        include_diary_features: Add aggregated diary features (only useful
            after continuous-learning retrains when enough diary data exists).

    Returns:
        DataFrame with columns for all features + Yield_kg_per_ha.
    """
    print('[DATA] Loading World Bank Ghana indicators …')
    wb = load_world_bank_ghana()
    fert_by_yr  = _fill_wb_series(wb, 'national_fertilizer_kg_ha')
    land_by_yr  = _fill_wb_series(wb, 'national_agri_land_km2')

    # Compute global means as fallback for missing WB years
    fert_mean = float(np.mean(list(fert_by_yr.values()))) if fert_by_yr else 15.0
    land_mean = float(np.mean(list(land_by_yr.values()))) if land_by_yr else 148000.0

    diary_agg = {}
    harvest_rows = []
    if use_db:
        print('[DATA] Loading DB records …')
        harvest_rows, diary_rows = load_db_data()
        print(f'       harvest_submissions: {len(harvest_rows)}')
        print(f'       diary entries:       {len(diary_rows)}')
        diary_agg = aggregate_diary(diary_rows)

    records = []

    # ── 1. Historical CSV ─────────────────────────────────────────────────────
    hist_df = load_historical()
    if not hist_df.empty:
        for _, row in hist_df.iterrows():
            y = _flt(row.get('Yield_kg_per_ha'), None)
            if y is None or y <= 0:
                continue
            yr = int(row.get('Year') or 2020)
            rec = {
                'Area_Planted_ha':           _flt(row.get('Area_Planted_ha'), 2.0),
                'Year':                      yr,
                'Crop':                      str(row.get('Crop') or '').strip(),
                'Region':                    str(row.get('Region') or '').strip(),
                'District':                  str(row.get('District') or '').strip(),
                'national_fertilizer_kg_ha': fert_by_yr.get(yr, fert_mean),
                'national_agri_land_km2':    land_by_yr.get(yr, land_mean),
                'Production_tonnes':         _flt(row.get('Production_tonnes'), None),
                'Yield_kg_per_ha':           y,
                'source':                    'historical',
            }
            if include_diary_features:
                for f in DIARY_FEATURES:
                    rec[f] = None  # filled with means later
            records.append(rec)
        print(f'[DATA] Historical CSV rows:        {len(records)}')

    # ── 2. Farmer harvest submissions ─────────────────────────────────────────
    sub_count = 0
    for row in harvest_rows:
        y = _flt(row.get('actual_yield_kg_per_ha'), None)
        if y is None or y <= 0:
            continue
        yr        = int(row.get('year') or 2026)
        farmer_id = row.get('farmer_id')
        crop      = (row.get('crop') or '').strip()
        diary_key = (farmer_id, crop, yr)
        diary_f   = diary_agg.get(diary_key, {})
        rec = {
            'Area_Planted_ha':           _flt(row.get('area_hectares'), 2.0),
            'Year':                      yr,
            'Crop':                      crop,
            'Region':                    (row.get('region') or '').strip(),
            'District':                  (row.get('district') or '').strip(),
            'national_fertilizer_kg_ha': fert_by_yr.get(yr, fert_mean),
            'national_agri_land_km2':    land_by_yr.get(yr, land_mean),
            'Yield_kg_per_ha':           y,
            'source':                    'farmer_submission',
        }
        if include_diary_features:
            for f in DIARY_FEATURES:
                rec[f] = diary_f.get(f)
            rec['quality_score'] = _flt(row.get('quality_score'), None)
        records.append(rec)
        sub_count += 1

    if sub_count:
        print(f'[DATA] Farmer submission rows:     {sub_count}')

    df = pd.DataFrame(records)
    print(f'[DATA] Total records:              {len(df)}')
    return df


# ── Feature engineering ────────────────────────────────────────────────────────

CORE_FEATURES = [
    'Area_Planted_ha', 'Year',
    'Crop_encoded', 'Region_encoded', 'District_encoded',
    'national_fertilizer_kg_ha', 'national_agri_land_km2',
]


def prepare_features(df: pd.DataFrame,
                     include_diary: bool = False,
                     encoders: dict = None,
                     feature_defaults: dict = None):
    """
    Encode categoricals, fill missing values, return (X, y, encoders, defaults).

    Pass `encoders` to reuse existing encoders (for transform-only, e.g. inference).
    """
    df = df.copy()
    df = df[df['Yield_kg_per_ha'].notna() & (df['Yield_kg_per_ha'] > 0)].copy()

    # Fill missing WB values
    for col in ['national_fertilizer_kg_ha', 'national_agri_land_km2']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
            df[col] = df[col].fillna(df[col].median())

    # Encode categoricals
    fit_mode  = encoders is None
    encoders  = encoders or {}
    for col in ['Crop', 'Region', 'District']:
        df[col] = df[col].fillna('Unknown')
        if fit_mode:
            le = LabelEncoder()
            df[col + '_encoded'] = le.fit_transform(df[col].astype(str))
            encoders[col] = le
        else:
            le = encoders[col]
            df[col + '_encoded'] = df[col].astype(str).map(
                lambda v, le=le: (
                    le.transform([v])[0]
                    if v in le.classes_
                    else float(np.mean(le.transform(le.classes_)))
                )
            )

    feature_list = list(CORE_FEATURES)

    if include_diary:
        # Compute defaults from data (for missing diary values)
        computed_defaults = feature_defaults or {}
        for feat in DIARY_FEATURES:
            if feat not in df.columns:
                df[feat] = None
            col_vals = pd.to_numeric(df[feat], errors='coerce').dropna()
            if feat not in computed_defaults:
                computed_defaults[feat] = (
                    float(col_vals.mean()) if len(col_vals) > 0
                    else DIARY_DEFAULTS[feat]
                )
            df[feat] = pd.to_numeric(df[feat], errors='coerce').fillna(
                computed_defaults[feat]
            )
        feature_list = feature_list + DIARY_FEATURES
        feature_defaults = computed_defaults
    else:
        feature_defaults = feature_defaults or {}

    X = df[feature_list].copy()
    X = X.fillna(X.median(numeric_only=True))
    y = df['Yield_kg_per_ha'].astype(float)

    mask = y.notna() & X.notna().all(axis=1)
    return (X[mask].reset_index(drop=True),
            y[mask].reset_index(drop=True),
            encoders,
            feature_defaults)


def get_train_test_split(df: pd.DataFrame,
                         include_diary: bool = False,
                         test_size: float = 0.2,
                         random_state: int = 42):
    """
    Full pipeline: prepare features, split, return everything needed for training.
    """
    X, y, encoders, defaults = prepare_features(df, include_diary=include_diary)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state
    )
    return X_train, X_test, y_train, y_test, encoders, defaults


# ── Utility ────────────────────────────────────────────────────────────────────

def _flt(val, default):
    if val is None:
        return default
    try:
        return float(val)
    except Exception:
        return default
