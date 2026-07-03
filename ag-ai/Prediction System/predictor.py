"""
AgriGuard Unified Predictor — Prediction System
================================================

Loads any model saved by train_baseline.py, train_advanced.py, or
compare_models.py and provides a clean inference interface.

Usage:
    from predictor import AgriGuardPredictor

    p = AgriGuardPredictor()           # loads best_model.joblib by default
    result = p.predict(
        crop='Maize', region='Ashanti', area_ha=2.5, year=2026
    )
    print(result['predicted_yield_kg_per_ha'])
"""

import numpy as np
import pandas as pd
import joblib
from pathlib import Path

MODEL_DIR = Path(__file__).resolve().parent / 'models'

# Maps any incoming crop name (FAOSTAT long names, app aliases) → canonical model name
_CROP_ALIASES: dict[str, str] = {
    'Maize (corn)':            'Maize',
    'Corn':                    'Maize',
    'Cassava, fresh':           'Cassava',
    'Yams':                    'Yam',
    'Plantains and cooking bananas': 'Plantain',
    'Cow peas, dry':           'Cowpea',
    'Groundnuts, excluding shelled': 'Groundnuts',
    'Peanuts':                 'Groundnuts',
    'Taro':                    'Cocoyam',
    'Cocoa beans':             'Cocoa',
    'Cacao':                   'Cocoa',
    'Soya beans':              'Soybean',
    'Soybeans':                'Soybean',
    'Seed cotton, unginned':   'Cotton',
    'Oil palm fruit':          'Oil Palm',
    'Palm Oil':                'Oil Palm',
    'Chillies and peppers, green (Capsicum spp. and Pimenta spp.)': 'Pepper (Green)',
    'Chillies and peppers, dry (Capsicum spp., Pimenta spp.), raw': 'Pepper (Dry)',
    'Pepper':                  'Pepper (Green)',
    'Karite nuts (sheanuts)':  'Shea Nuts',
    'Sheanuts':                'Shea Nuts',
    'Groundnuts, excluding shelled': 'Groundnuts',
    'Edible roots and tubers with high starch or inulin content, n.e.c., fresh': 'Other Tubers',
    'Other beans, green':      'Green Beans',
    'Cantaloupes and other melons': 'Melons',
    'Natural rubber in primary forms': 'Rubber',
    'Mangoes, guavas and mangosteens': 'Mangoes',
    'Onions and shallots, dry (excluding dehydrated)': 'Onions',
    'Other fruits, n.e.c.':   'Other Fruits',
    'Other nuts (excluding wild edible nuts and groundnuts), in shell, n.e.c.': 'Other Nuts',
    'Other oil seeds, n.e.c.': 'Other Oil Seeds',
    'Other pulses n.e.c.':    'Other Pulses',
    'Other vegetables, fresh n.e.c.': 'Other Vegetables',
    'Pepper (Piper spp.), raw': 'Black Pepper',
    'Unmanufactured tobacco':  'Tobacco',
    'Beans, dry':              'Beans',
    'Cashew nuts, in shell':   'Cashew',
    'Eggplants (aubergines)': 'Eggplant',
    'Lemons and limes':        'Citrus',
    'Ginger, raw':             'Ginger, raw',   # keep as-is
    'Coffee, green':           'Coffee, green',  # keep as-is
    'Tomato':                  'Tomatoes',
}


def _normalise_crop(name: str) -> str:
    """Map any crop alias to its canonical model name."""
    return _CROP_ALIASES.get(str(name).strip(), str(name).strip())


# Default fallback values for diary / weather features when not supplied
_DIARY_DEFAULTS = {
    'avg_temp_max_c':        31.0,
    'avg_temp_min_c':        22.0,
    'total_rainfall_mm':     800.0,
    'gdd':                  1200.0,
    'fertilizer_kg_ha':      50.0,
    'fertilizer_applications': 2.0,
    'pest_events':            0.0,
    'disease_events':         0.0,
    'irrigation_days':        0.0,
    'quality_score':          7.0,
}


class AgriGuardPredictor:
    """
    Unified predictor. Loads a model artifact produced by the Prediction System
    training scripts and exposes:
      - predict()                    — single farm / query prediction
      - predict_batch()              — batch predictions
      - predict_regional_aggregate() — regional average prediction
    """

    def __init__(self, model_path: str = None):
        if model_path is None:
            # Try best_model first, then advanced, then baseline
            for name in ('best_model.joblib', 'advanced_model.joblib',
                         'baseline_model.joblib'):
                p = MODEL_DIR / name
                if p.exists():
                    model_path = str(p)
                    break
        if model_path is None:
            raise FileNotFoundError(
                f'No model file found in {MODEL_DIR}. '
                'Run compare_models.py or train_baseline.py first.'
            )

        self._artifact  = joblib.load(model_path)
        self._model     = self._artifact['model']
        self._encoders  = self._artifact['encoders']
        self._features  = self._artifact['features']
        self._defaults  = self._artifact.get('feature_defaults', {})
        self._metrics   = self._artifact['metrics']
        self._model_type = self._artifact.get('model_type', 'Unknown')
        self._model_path = model_path

    # ── Public API ─────────────────────────────────────────────────────────────

    def predict(self,
                crop: str,
                region: str,
                area_ha: float,
                year: int = None,
                district: str = None,
                diary: dict = None,
                weather: dict = None) -> dict:
        """
        Predict yield for a single farm/query.

        Args:
            crop:     Crop name  (e.g. 'Maize', 'Cassava')
            region:   Ghana region (e.g. 'Ashanti', 'Northern')
            area_ha:  Farm area in hectares
            year:     Harvest year (default: current year)
            district: District name (optional)
            diary:    Dict of aggregated diary features (optional):
                        avg_temp_max_c, avg_temp_min_c, total_rainfall_mm,
                        gdd, fertilizer_kg_ha, pest_events, disease_events,
                        irrigation_days, quality_score
            weather:  Dict with weather keys (optional, used to derive diary
                        features when diary is not provided):
                        temperatureC, rainfallNext24hMm, humidity

        Returns:
            Dict with predicted_yield_kg_per_ha, confidence intervals,
            production estimates, model metadata.
        """
        import datetime as _dt
        if year is None:
            year = _dt.datetime.now().year
        crop = _normalise_crop(crop)

        X = self._build_X(crop, region, area_ha, year, district, diary, weather)
        base_yield = float(self._model.predict(X)[0])

        # Per-tree variance for confidence interval
        try:
            tree_preds = np.array([t.predict(X)[0] for t in self._model.estimators_])
            std = float(np.std(tree_preds))
        except Exception:
            std = base_yield * 0.10

        ci_lower = max(0, base_yield - 1.96 * std)
        ci_upper = base_yield + 1.96 * std

        return {
            'status':                    'success',
            'model_type':                self._model_type,
            'model_r2_test':             round(self._metrics.get('r2_test', 0), 4),
            'crop':                      crop,
            'region':                    region,
            'district':                  district or 'Unknown',
            'year':                      year,
            'area_ha':                   area_ha,
            'predicted_yield_kg_per_ha': round(base_yield, 1),
            'confidence_interval_lower': round(ci_lower, 1),
            'confidence_interval_upper': round(ci_upper, 1),
            'predicted_production_kg':   round(base_yield * area_ha, 1),
            'predicted_production_tonnes': round(base_yield * area_ha / 1000, 3),
        }

    def predict_batch(self, items: list) -> list:
        """
        Batch prediction. Each item in `items` is a dict with keys:
            crop, region, area_ha, year (optional), district (optional)
        """
        return [self.predict(**item) for item in items]

    def predict_regional_aggregate(self,
                                   crop: str,
                                   region: str,
                                   year: int = None) -> dict:
        """
        Regional-level aggregate using average farm sizes per region.
        """
        _AVG_FARM_SIZE = {
            'ASHANTI': 2.1, 'BRONG AHAFO': 2.6, 'CENTRAL': 2.0,
            'EASTERN': 2.2, 'GREATER ACCRA': 1.8, 'NORTHERN': 3.0,
            'UPPER EAST': 2.4, 'UPPER WEST': 2.8, 'VOLTA': 2.3, 'WESTERN': 2.5,
        }
        avg_area = _AVG_FARM_SIZE.get(region.upper(), 2.3)
        result = self.predict(crop=crop, region=region, area_ha=avg_area, year=year)
        result['forecast_type']          = 'regional_aggregate'
        result['average_farm_size_ha']   = avg_area
        return result

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _encode(self, col: str, value: str) -> float:
        le = self._encoders.get(col)
        if le is None:
            return 0.0
        try:
            return float(le.transform([value])[0])
        except ValueError:
            return float(np.mean(le.transform(le.classes_)))

    def _wb_val(self, feat: str, year: int) -> float:
        """Best-effort lookup for national WB features."""
        return self._defaults.get(feat, 0.0)

    def _diary_val(self, feat: str, diary: dict, weather: dict) -> float:
        if diary and feat in diary and diary[feat] is not None:
            return float(diary[feat])
        # Try to derive from weather dict
        if weather and isinstance(weather, dict):
            mapping = {
                'avg_temp_max_c':    weather.get('temperatureC') or weather.get('temp_max_c'),
                'avg_temp_min_c':    weather.get('temp_min_c'),
                'total_rainfall_mm': weather.get('rainfallNext24hMm') or weather.get('rainfall_mm'),
            }
            if feat in mapping and mapping[feat] is not None:
                return float(mapping[feat])
        # Fall back to model defaults, then hardcoded
        return float(
            self._defaults.get(feat)
            or _DIARY_DEFAULTS.get(feat, 0.0)
        )

    def _build_X(self, crop, region, area_ha, year, district, diary, weather):
        crop = _normalise_crop(crop)
        base = {
            'Area_Planted_ha':           float(area_ha),
            'Year':                      float(year),
            'Crop_encoded':              self._encode('Crop', crop),
            'Region_encoded':            self._encode('Region', region or 'Unknown'),
            'District_encoded':          self._encode('District', district or 'Unknown'),
            'national_fertilizer_kg_ha': self._wb_val('national_fertilizer_kg_ha', year),
            'national_agri_land_km2':    self._wb_val('national_agri_land_km2', year),
        }

        diary_feats = [
            'avg_temp_max_c', 'avg_temp_min_c', 'total_rainfall_mm', 'gdd',
            'fertilizer_kg_ha', 'fertilizer_applications', 'pest_events',
            'disease_events', 'irrigation_days', 'quality_score',
        ]
        for f in diary_feats:
            base[f] = self._diary_val(f, diary, weather)

        row = [base.get(f, 0.0) for f in self._features]
        return pd.DataFrame([row], columns=self._features)

    # ── Info ───────────────────────────────────────────────────────────────────

    @property
    def model_info(self) -> dict:
        return {
            'model_type':  self._model_type,
            'model_path':  self._model_path,
            'features':    self._features,
            'metrics':     self._metrics,
        }
