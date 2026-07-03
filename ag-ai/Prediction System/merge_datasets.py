"""
Merge all AgriGuard data sources into one comprehensive training CSV.

Sources:
  1. agri_guard_training_data_regional.csv  — regional breakdown for 8 main crops + national for rest
  2. FAOSTAT_data_en_6-16-2026.csv          — national Area, Production, Yield for 50 crops 2012-2024
  3. World Bank WB_FERT / WB_LAND CSVs      — fertilizer kg/ha, agri land km² by year

Output: dataset/data/historical/agri_guard_merged_training_data.csv
"""

import pandas as pd
import numpy as np
from pathlib import Path
import sys
sys.stdout.reconfigure(encoding='utf-8')

PROJECT_ROOT = Path(__file__).resolve().parent.parent
HIST_DIR     = PROJECT_ROOT / 'dataset' / 'data' / 'historical'
DATASET_DIR  = PROJECT_ROOT / 'dataset'

WB_FERT_CSV = DATASET_DIR / 'API_AG.CON.FERT.ZS_DS2_en_csv_v2_393435' / 'API_AG.CON.FERT.ZS_DS2_en_csv_v2_393435.csv'
WB_LAND_CSV = DATASET_DIR / 'API_AG.LND.AGRI.K2_DS2_en_csv_v2_350995' / 'API_AG.LND.AGRI.K2_DS2_en_csv_v2_350995.csv'

# ── Canonical crop name map ────────────────────────────────────────────────────
# Any alias → single canonical name used across the entire merged dataset
CROP_ALIASES = {
    # FAOSTAT long names → simplified
    'Maize (corn)':                           'Maize',
    'Cassava, fresh':                          'Cassava',
    'Yams':                                    'Yam',
    'Plantains and cooking bananas':           'Plantain',
    'Cow peas, dry':                           'Cowpea',
    'Groundnuts, excluding shelled':           'Groundnuts',
    'Taro':                                    'Cocoyam',
    'Cocoa beans':                             'Cocoa',
    'Soya beans':                              'Soybean',
    'Seed cotton, unginned':                   'Cotton',
    'Oil palm fruit':                          'Oil Palm',
    'Chillies and peppers, green (Capsicum spp. and Pimenta spp.)': 'Pepper (Green)',
    'Chillies and peppers, dry (Capsicum spp., Pimenta spp.), raw': 'Pepper (Dry)',
    'Karite nuts (sheanuts)':                  'Shea Nuts',
    'Edible roots and tubers with high starch or inulin content, n.e.c., fresh': 'Other Tubers',
    'Other beans, green':                      'Green Beans',
    'Cantaloupes and other melons':            'Melons',
    'Coir, raw':                               'Coir',
    'Natural rubber in primary forms':         'Rubber',
    'Mangoes, guavas and mangosteens':         'Mangoes',
    'Onions and shallots, dry (excluding dehydrated)': 'Onions',
    'Other fruits, n.e.c.':                   'Other Fruits',
    'Other nuts (excluding wild edible nuts and groundnuts), in shell, n.e.c.': 'Other Nuts',
    'Other oil seeds, n.e.c.':                'Other Oil Seeds',
    'Other pulses n.e.c.':                    'Other Pulses',
    'Other vegetables, fresh n.e.c.':         'Other Vegetables',
    'Pepper (Piper spp.), raw':                'Black Pepper',
    'Unmanufactured tobacco':                  'Tobacco',
    'Beans, dry':                              'Beans',
    'Cashew nuts, in shell':                   'Cashew',
    'Eggplants (aubergines)':                 'Eggplant',
    'Lemons and limes':                        'Citrus',
    # Regional short names that stay as-is (identity mappings for clarity)
    'Maize':      'Maize',
    'Cassava':    'Cassava',
    'Yam':        'Yam',
    'Plantain':   'Plantain',
    'Cowpea':     'Cowpea',
    'Groundnuts': 'Groundnuts',
    'Cocoyam':    'Cocoyam',
    'Rice':       'Rice',
    'Millet':     'Millet',
    'Sorghum':    'Sorghum',
}

def normalise_crop(name: str) -> str:
    return CROP_ALIASES.get(str(name).strip(), str(name).strip())


def _load_wb(csv_path, country='GHA'):
    if not csv_path.exists():
        print(f'  [WARN] {csv_path.name} not found')
        return {}
    df = pd.read_csv(csv_path, skiprows=4)
    row = df[df['Country Code'] == country]
    if row.empty:
        return {}
    row = row.iloc[0]
    out = {}
    for col in df.columns[4:]:
        try:
            yr = int(col)
            val = row[col]
            if pd.notna(val):
                out[yr] = float(val)
        except Exception:
            continue
    return out


def _fill(series_dict):
    """Forward-fill then backward-fill missing years."""
    if not series_dict:
        return {}
    years = sorted(series_dict)
    filled = {}
    last = None
    for yr in range(min(years), max(years) + 1):
        if yr in series_dict:
            last = series_dict[yr]
        if last is not None:
            filled[yr] = last
    # backward fill
    if filled:
        first = filled[min(filled)]
        for yr in range(min(years), max(years) + 1):
            if yr not in filled:
                filled[yr] = first
    return filled


def main():
    print('=== AgriGuard Dataset Merge ===\n')

    # ── 1. World Bank indicators ───────────────────────────────────────────────
    print('[1] Loading World Bank indicators...')
    fert_raw = _load_wb(WB_FERT_CSV)
    land_raw = _load_wb(WB_LAND_CSV)
    fert_by_yr = _fill(fert_raw)
    land_by_yr = _fill(land_raw)
    fert_mean = float(np.mean(list(fert_by_yr.values()))) if fert_by_yr else 15.0
    land_mean = float(np.mean(list(land_by_yr.values()))) if land_by_yr else 148000.0
    print(f'   Fertilizer years: {min(fert_by_yr) if fert_by_yr else "N/A"}-{max(fert_by_yr) if fert_by_yr else "N/A"}')
    print(f'   Land area years:  {min(land_by_yr) if land_by_yr else "N/A"}-{max(land_by_yr) if land_by_yr else "N/A"}')

    # ── 2. FAOSTAT raw → wide pivot ────────────────────────────────────────────
    print('\n[2] Loading FAOSTAT raw data...')
    fao_raw = pd.read_csv(HIST_DIR / 'FAOSTAT_data_en_6-16-2026.csv', encoding='utf-8-sig')
    fao_raw['Year']  = pd.to_numeric(fao_raw['Year'],  errors='coerce')
    fao_raw['Value'] = pd.to_numeric(fao_raw['Value'], errors='coerce')

    fao_pivot = fao_raw.pivot_table(
        index=['Item', 'Year'],
        columns='Element',
        values='Value',
        aggfunc='first',
    ).reset_index()
    fao_pivot.columns.name = None
    fao_pivot = fao_pivot.rename(columns={
        'Item':            'Crop_fao',
        'Area harvested':  'Area_Planted_ha',
        'Production':      'Production_tonnes',
        'Yield':           'Yield_kg_per_ha',   # already in kg/ha per FAOSTAT metadata
    })
    fao_pivot['Crop'] = fao_pivot['Crop_fao'].map(normalise_crop)
    fao_pivot['Region']   = 'Ghana (National)'
    fao_pivot['District'] = ''
    fao_pivot['source']   = 'FAOSTAT_national'
    print(f'   FAOSTAT rows (pivoted): {len(fao_pivot)}')
    print(f'   FAOSTAT crops: {fao_pivot["Crop"].nunique()}')

    # ── 3. Regional master CSV ─────────────────────────────────────────────────
    print('\n[3] Loading regional master CSV...')
    reg = pd.read_csv(HIST_DIR / 'agri_guard_training_data_regional.csv', encoding='utf-8-sig')
    reg['Year'] = pd.to_numeric(reg['Year'], errors='coerce')
    reg['Area_Planted_ha']   = pd.to_numeric(reg['Area_Planted_ha'],   errors='coerce')
    reg['Yield_kg_per_ha']   = pd.to_numeric(reg['Yield_kg_per_ha'],   errors='coerce')
    reg['Production_tonnes'] = pd.to_numeric(reg.get('Production_tonnes', pd.Series()), errors='coerce')
    reg['source'] = 'regional'
    print(f'   Regional rows: {len(reg)}')
    print(f'   Regional crops: {reg["Crop"].nunique()}')
    print(f'   Regions: {sorted(reg["Region"].dropna().unique())}')

    # Identify which crops have TRUE regional data (multiple regions per crop)
    region_counts = reg.groupby('Crop')['Region'].nunique()
    regional_crops = set(region_counts[region_counts > 1].index)
    national_only_crops = set(region_counts[region_counts <= 1].index)
    print(f'\n   Crops with regional breakdown ({len(regional_crops)}): {sorted(regional_crops)}')
    print(f'   National-only crops in regional CSV ({len(national_only_crops)}): {len(national_only_crops)} crops')

    # ── 4. Build merged dataset ────────────────────────────────────────────────
    print('\n[4] Merging datasets...')

    # 4a. Regional master rows — normalise crop names
    merged_rows = []
    seen_national = set()   # track (canonical_crop, year) already in regional CSV

    for _, row in reg.iterrows():
        yr   = int(row['Year']) if pd.notna(row['Year']) else 2020
        y    = float(row['Yield_kg_per_ha']) if pd.notna(row['Yield_kg_per_ha']) else None
        if y is None or y <= 0:
            continue
        crop   = normalise_crop(row['Crop'])
        region = str(row.get('Region', 'Ghana (National)')).strip()
        prod   = float(row['Production_tonnes']) if pd.notna(row.get('Production_tonnes', None)) else None

        merged_rows.append({
            'Crop':                      crop,
            'Region':                    region,
            'District':                  str(row.get('District', '')).strip(),
            'Year':                      yr,
            'Area_Planted_ha':           float(row['Area_Planted_ha']) if pd.notna(row['Area_Planted_ha']) else 10.0,
            'Yield_kg_per_ha':           y,
            'Production_tonnes':         prod,
            'national_fertilizer_kg_ha': fert_by_yr.get(yr, fert_mean),
            'national_agri_land_km2':    land_by_yr.get(yr, land_mean),
            'source':                    'regional' if region != 'Ghana (National)' else 'national_csv',
        })
        if region == 'Ghana (National)':
            seen_national.add((crop, yr))

    regional_count = len(merged_rows)
    print(f'   Regional master rows added (after normalisation): {regional_count}')

    # 4b. FAOSTAT pivot — add national rows for crops/years NOT already represented
    faostat_added = 0
    for _, row in fao_pivot.iterrows():
        crop = normalise_crop(row['Crop_fao'])
        yr   = int(row['Year']) if pd.notna(row['Year']) else 0
        y    = float(row['Yield_kg_per_ha']) if pd.notna(row.get('Yield_kg_per_ha')) else None
        area = float(row['Area_Planted_ha']) if pd.notna(row.get('Area_Planted_ha')) else None
        prod = float(row['Production_tonnes']) if pd.notna(row.get('Production_tonnes')) else None

        if y is None or y <= 0 or yr == 0:
            continue
        if (crop, yr) in seen_national:
            continue   # already covered by regional CSV national row

        merged_rows.append({
            'Crop':                      crop,
            'Region':                    'Ghana (National)',
            'District':                  '',
            'Year':                      yr,
            'Area_Planted_ha':           area if area and area > 0 else 100.0,
            'Yield_kg_per_ha':           y,
            'Production_tonnes':         prod,
            'national_fertilizer_kg_ha': fert_by_yr.get(yr, fert_mean),
            'national_agri_land_km2':    land_by_yr.get(yr, land_mean),
            'source':                    'FAOSTAT_national',
        })
        seen_national.add((crop, yr))
        faostat_added += 1

    print(f'   FAOSTAT national rows added: {faostat_added}')

    # ── 5. Assemble DataFrame ─────────────────────────────────────────────────
    df = pd.DataFrame(merged_rows)
    df = df.dropna(subset=['Yield_kg_per_ha'])
    df = df[df['Yield_kg_per_ha'] > 0]
    df = df.reset_index(drop=True)

    print(f'\n[5] Final merged dataset:')
    print(f'   Total rows: {len(df)}')
    print(f'   Total crops: {df["Crop"].nunique()}')
    print(f'   Year range: {int(df["Year"].min())} - {int(df["Year"].max())}')
    print(f'   Regions: {sorted(df["Region"].unique())}')
    print(f'   Sources: {df["source"].value_counts().to_dict()}')

    print('\n   Rows per crop:')
    for crop, cnt in df.groupby('Crop').size().sort_values(ascending=False).items():
        print(f'     {cnt:4d}  {crop}')

    # ── 6. Save ───────────────────────────────────────────────────────────────
    out_path = HIST_DIR / 'agri_guard_merged_training_data.csv'
    df.to_csv(out_path, index=False, encoding='utf-8')
    print(f'\n[6] Saved → {out_path}')
    print(f'    Columns: {list(df.columns)}')

    return df


if __name__ == '__main__':
    main()
