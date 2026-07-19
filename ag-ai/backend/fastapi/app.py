import sys
import os
# Ensure project root is on sys.path for local imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Optional
import tempfile
import base64
import json
import traceback
import datetime
import asyncio
import threading

# Load .env before importing db
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
except ImportError:
    pass

try:
    from backend.fastapi.db import (
        init_db, insert_submission as db_insert,
        hide_submission as db_hide, query_actuals, query_my_submissions,
        create_user, find_user_by_email, soft_delete_user,
        insert_diary_entry, query_my_diary, hide_diary_entry,
        query_diary_for_season, query_diary_for_crop_year, query_all_for_training,
        admin_stats, admin_all_users, admin_all_submissions, admin_all_diary,
        log_buyer_activity, admin_buyer_activity, admin_buyer_stats,
        query_my_activity, delete_activity_entry, clear_my_activity,
        update_user_profile,
        get_crop_list, get_gdd_config, get_crop_areas,
        upsert_crop, deactivate_crop, all_crops_config,
        count_submissions, save_model_artifact, load_model_artifact,
        verify_user_for_reset, update_user_password,
        find_or_create_google_user, update_user_role,
    )
except Exception:
    from db import (
        init_db, insert_submission as db_insert,
        hide_submission as db_hide, query_actuals, query_my_submissions,
        create_user, find_user_by_email, soft_delete_user,
        insert_diary_entry, query_my_diary, hide_diary_entry,
        query_diary_for_season, query_diary_for_crop_year, query_all_for_training,
        admin_stats, admin_all_users, admin_all_submissions, admin_all_diary,
        log_buyer_activity, admin_buyer_activity, admin_buyer_stats,
        query_my_activity, delete_activity_entry, clear_my_activity,
        update_user_profile,
        get_crop_list, get_gdd_config, get_crop_areas,
        upsert_crop, deactivate_crop, all_crops_config,
        count_submissions, save_model_artifact, load_model_artifact,
        verify_user_for_reset, update_user_password,
        find_or_create_google_user, update_user_role,
    )

ADMIN_EMAIL    = os.getenv('ADMIN_EMAIL')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD')
if not ADMIN_EMAIL or not ADMIN_PASSWORD:
    raise RuntimeError('ADMIN_EMAIL and ADMIN_PASSWORD must be set in .env')

# ── Request schemas (give Swagger proper docs) ─────────────────────────────────

class YieldForecastRequest(BaseModel):
    crop: str = Field(..., example='Maize', description='Crop you are growing')
    region: str = Field(..., example='Ashanti', description='Ghana region')
    area: float = Field(..., example=2.5, description='Farm area in hectares')
    district: Optional[str] = Field(None, example='Kumasi', description='District (optional)')
    year: Optional[int] = Field(None, example=2026, description='Harvest year (defaults to current)')
    symptoms: Optional[str] = Field(None, example='yellowing leaves', description='Observed symptoms (optional)')
    quality_score: Optional[float] = Field(None, example=7.5, description='Expected quality 1–10 (optional)')
    observed_disease: Optional[str] = Field(None, example='Common rust', description='Known disease (optional)')
    weather_record: Optional[dict] = Field(None, description='Weather data object (optional)')
    farmer_id: Optional[str] = Field(None, example='farmer_001')

class BuyerForecastRequest(BaseModel):
    crop: Optional[str] = Field(None, example='Maize', description='Filter by crop')
    region: Optional[str] = Field(None, example='Ashanti', description='Filter by Ghana region')
    district: Optional[str] = Field(None, example='Kumasi', description='Filter by district')
    year: Optional[int] = Field(None, example=2026, description='Harvest year')

class PostHarvestRequest(BaseModel):
    farmer_id: Optional[str] = Field(None, example='farmer_001')
    crop: str = Field(..., example='Rice')
    region: str = Field(..., example='Oti')
    district: Optional[str] = Field(None, example='Krachi East')
    town: Optional[str] = Field(None, example='Kete-Krachi')
    area_hectares: float = Field(..., example=2.5)
    actual_yield_kg: float = Field(..., example=3500.0)
    quantity_available_kg: Optional[float] = Field(None, example=3000.0)
    price_per_kg_ghs: Optional[float] = Field(None, example=4.50)
    phone: Optional[str] = Field(None, example='024 XXX XXXX')
    quality_score: Optional[float] = Field(None, example=7.0)
    notes: Optional[str] = Field(None)
    year: Optional[int] = Field(None)
    consent_market: bool = Field(False, description='Farmer consents to listing in buyer marketplace')
    consent_training: bool = Field(False, description='Farmer consents to data use for model training')

class TextDiagnoseRequest(BaseModel):
    crop: str = Field(..., example='Maize', description='Crop with symptoms')
    region: str = Field(..., example='Ashanti', description='Ghana region')
    symptoms: Optional[str] = Field(None, example='yellowing leaves, brown spots on lower leaves')
    quality_score: Optional[float] = Field(None, example=6.0)
    observed_disease: Optional[str] = Field(None, example='Common rust')
    weather_record: Optional[dict] = Field(None)

# ── Directory constants ────────────────────────────────────────────────────────
_PS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'Prediction System'))
_AS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'Advisory system'))

# ── Advisory System imports (disease model + utils live here after reorganisation)
if _AS_DIR not in sys.path:
    sys.path.insert(0, _AS_DIR)

try:
    from disease_model import infer_image, load_inference_assets
except Exception as _e:
    print(f'[WARN] disease_model unavailable: {_e}')
    infer_image = None
    load_inference_assets = None

try:
    from disease_utils import get_disease_details, clean_disease_label
except Exception:
    try:
        from backend.disease_utils import get_disease_details, clean_disease_label
    except Exception:
        def get_disease_details(label): return {'disease_name': label, 'treatment': [], 'prevention': []}
        def clean_disease_label(label): return label.replace('___', ' - ').replace('_', ' ').title()

# ── Prediction System imports ──────────────────────────────────────────────────
AgriGuardPredictor = None
try:
    if _PS_DIR not in sys.path:
        sys.path.insert(0, _PS_DIR)
    from predictor import AgriGuardPredictor
except Exception as _e:
    print(f'[WARN] New predictor unavailable: {_e}')

_advisory_engine = None
try:
    from advisory_engine import AdvisoryEngine
    _advisory_engine = AdvisoryEngine()
except Exception as _e:
    print(f'[WARN] Advisory engine unavailable: {_e}')

app = FastAPI(title='AgriGuard FastAPI')


def _keepalive_loop():
    """Ping Neon every 3 min to keep compute awake (autosuspend threshold is 5 min)."""
    import time
    while True:
        time.sleep(180)
        try:
            from db import get_conn
            with get_conn() as c:
                c.cursor().execute('SELECT 1')
        except Exception:
            pass


@app.on_event('startup')
def startup():
    import time
    # Retry connecting to Neon for up to 3 minutes (handles cold-start autosuspend)
    connected = False
    for attempt in range(12):
        try:
            init_db()
            connected = True
            print(f'[DB] Connected (attempt {attempt + 1})')
            break
        except Exception as e:
            print(f'[DB] Attempt {attempt + 1}/12 failed: {e}')
            time.sleep(15)

    if not connected:
        print('[WARN] Database not available after 12 attempts.')
        print('[WARN] Set DATABASE_URL in .env to enable cloud storage.')
        return

    # One-time migration from legacy JSON file if it exists
    json_path = os.path.join('farmer_submissions', 'post_harvest.json')
    if os.path.exists(json_path):
        try:
            from db import migrate_from_json
        except ImportError:
            from backend.fastapi.db import migrate_from_json
        n = migrate_from_json(json_path)
        if n:
            print(f'[DB] Migrated {n} records from post_harvest.json')

    # Restore best model from Supabase if on-disk version is missing or older
    try:
        result = load_model_artifact('best_model')
        if result is not None:
            model_bytes, meta = result
            disk_path = os.path.join(_PS_DIR, 'models', 'best_model.joblib')
            db_trained_at = (meta or {}).get('trained_at', '')
            disk_trained_at = ''
            if os.path.exists(disk_path):
                import joblib as _jl
                try:
                    _art = _jl.load(disk_path)
                    disk_trained_at = _art.get('trained_at', '')
                except Exception:
                    pass
            db_r2   = (meta or {}).get('r2_test', 0.0)
            disk_r2 = 0.0
            if os.path.exists(disk_path):
                try:
                    disk_r2 = (_jl.load(disk_path) if '_jl' in dir() else
                               __import__('joblib').load(disk_path)).get('metrics', {}).get('r2_test', 0.0)
                except Exception:
                    pass
            # Restore from Supabase if disk is missing OR Supabase model has better R²
            if not os.path.exists(disk_path) or db_r2 > disk_r2:
                os.makedirs(os.path.dirname(disk_path), exist_ok=True)
                with open(disk_path, 'wb') as _f:
                    _f.write(model_bytes)
                print(f'[DB] Restored best_model.joblib from Supabase (R²={db_r2:.4f} vs disk R²={disk_r2:.4f})')
            else:
                print(f'[DB] On-disk model kept (R²={disk_r2:.4f} >= Supabase R²={db_r2:.4f})')
    except Exception as _e:
        print(f'[WARN] Could not restore model from DB: {_e}')

    # Keep Supabase connection alive
    t = threading.Thread(target=_keepalive_loop, daemon=True)
    t.start()


app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

RAW_DIR = os.path.join('farmer_submissions', 'raw')
MODEL_PATH = os.path.join(_PS_DIR, 'models', 'best_model.joblib')
DISEASE_MODEL_DIR = os.path.join(_AS_DIR, 'models', 'disease')
_OVERVIEW_AREA_HA = 2.3  # default farm area used when no size is specified


def _load_predictor():
    """Load the GBM best model from the Prediction System."""
    if AgriGuardPredictor is None:
        raise RuntimeError('Prediction System predictor not available')
    best = os.path.join(_PS_DIR, 'models', 'best_model.joblib')
    adv  = os.path.join(_PS_DIR, 'models', 'advanced_model.joblib')
    base = os.path.join(_PS_DIR, 'models', 'baseline_model.joblib')
    for path in (best, adv, base):
        if os.path.exists(path):
            return AgriGuardPredictor(path)
    return AgriGuardPredictor()


def _predict_compat(predictor, crop, region, area_ha, year=None,
                    district=None, diary=None, weather=None):
    """
    Call new predictor.predict() and shape the result into the legacy
    {status, prediction:{...}} envelope the rest of app.py expects.
    """
    r = predictor.predict(crop=crop, region=region, area_ha=area_ha,
                          year=year, district=district, diary=diary, weather=weather)
    pred = {
        'crop':                      r.get('crop'),
        'region':                    r.get('region'),
        'district':                  r.get('district'),
        'year':                      r.get('year'),
        'predicted_yield_kg_per_ha': r.get('predicted_yield_kg_per_ha'),
        'adjusted_yield_kg_per_ha':  r.get('predicted_yield_kg_per_ha'),
        'predicted_production_tonnes': r.get('predicted_production_tonnes'),
        'area_hectares':             r.get('area_ha'),
        'confidence_interval_lower': r.get('confidence_interval_lower'),
        'confidence_interval_upper': r.get('confidence_interval_upper'),
        'model_r2_score':            r.get('model_r2_test'),
        'model_type':                r.get('model_type'),
    }
    return {'status': 'success', 'prediction': pred}

DISEASE_MODEL_ASSETS = None

# Disease recommendations with crop name, description, and treatment
DISEASE_RECOMMENDATIONS = {
    "Healthy": {
        "crop": "Corn/Maize",
        "disease_name": "No Disease",
        "description": "The crop is healthy with no visible signs of disease.",
        "treatment": "Continue regular maintenance: proper watering, fertilization, and pest monitoring.",
        "prevention": "Maintain good crop hygiene, rotate crops, and monitor regularly."
    },
    "Powdery": {
        "crop": "Corn/Maize",
        "disease_name": "Powdery Mildew",
        "description": "A fungal disease that appears as white powdery coating on leaves. Reduces photosynthesis and can weaken the plant.",
        "treatment": [
            "Spray with sulfur-based fungicides (e.g., sulfur dust or wettable sulfur)",
            "Use potassium bicarbonate spray for organic farming",
            "Apply neem oil (3-5% concentration) every 7-10 days",
            "Ensure good air circulation by pruning excessive foliage"
        ],
        "prevention": "Avoid overhead irrigation, maintain plant spacing, and remove infected leaves promptly."
    },
    "Rust": {
        "crop": "Corn/Maize",
        "disease_name": "Rust Disease",
        "description": "A fungal disease characterized by rusty/reddish-brown spots on leaves. Can severely reduce yield if untreated.",
        "treatment": [
            "Apply copper-based fungicides (e.g., Bordeaux mixture or copper sulfate)",
            "Use triazole fungicides (e.g., propiconazole) for severe infections",
            "Remove and burn infected leaves to prevent spread",
            "Apply fungicide at 7-10 day intervals until disease is controlled"
        ],
        "prevention": "Use disease-resistant varieties, maintain proper spacing, ensure good drainage, and monitor regularly."
    }
}


def get_disease_model_assets():
    global DISEASE_MODEL_ASSETS
    if DISEASE_MODEL_ASSETS is None and load_inference_assets is not None:
        try:
            DISEASE_MODEL_ASSETS = load_inference_assets(DISEASE_MODEL_DIR)
        except Exception as e:
            print(f"[ERROR] Failed to load disease model assets: {e}")
            traceback.print_exc()
            DISEASE_MODEL_ASSETS = None
    return DISEASE_MODEL_ASSETS


@app.get('/')
def root():
    return {
        'status': 'running',
        'message': 'Agri app is live',
        'endpoints': [
            '/health',
            '/api/get-prediction',
            '/api/buyer-predict',
            '/api/predict/post-harvest',
            '/api/diagnose-disease',
            '/api/diagnose-disease-image',
            '/docs',
            '/redoc',
        ],
    }


@app.get('/health')
def health():
    return {'status': 'ok'}


@app.post('/api/get-prediction')
def get_prediction(payload: YieldForecastRequest):
    if AgriGuardPredictor is None:
        raise HTTPException(status_code=500, detail='predictor_unavailable')

    try:
        predictor = _load_predictor()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'model_load_failed: {e}')

    # Look up farmer's diary entries for this crop/season and aggregate into
    # in-season features (rainfall, temperature, fertilizer, pest events, etc.)
    # so the prediction reflects actual growing conditions, not just historical averages.
    diary_features = None
    if payload.farmer_id:
        try:
            import sys as _sys
            _sys.path.insert(0, _PS_DIR)
            from data_prep import aggregate_diary as _agg_diary
            year = payload.year or datetime.datetime.now().year
            diary_rows = query_diary_for_crop_year(payload.farmer_id, payload.crop, year)
            if diary_rows:
                agg = _agg_diary(diary_rows)
                key = (payload.farmer_id, (payload.crop or '').strip(), year)
                diary_features = agg.get(key)
        except Exception:
            pass

    result = _predict_compat(
        predictor,
        crop=payload.crop,
        region=payload.region,
        area_ha=payload.area,
        district=payload.district,
        year=payload.year,
        weather=payload.weather_record,
        diary=diary_features,
    )

    # Attach disease/advisory assessment from Advisory Engine
    if _advisory_engine is not None:
        try:
            diagnosis = _advisory_engine.diagnose(
                crop=payload.crop,
                region=payload.region,
                symptoms=payload.symptoms,
                observed_disease=payload.observed_disease,
                weather=payload.weather_record,
                quality_score=payload.quality_score,
            )
            advisory = _advisory_engine.generate_advisory(
                crop=payload.crop,
                region=payload.region,
                disease_risk=diagnosis['disease_risk'],
                weather_risk=diagnosis.get('weather_risk', 0.0),
                quality_score=payload.quality_score,
            )
            adjusted = result['prediction'].get('predicted_yield_kg_per_ha', 0) * diagnosis.get('yield_factor', 1.0)
            result['prediction']['adjusted_yield_kg_per_ha'] = round(adjusted, 1)
            result['prediction']['disease_assessment'] = {
                'disease':  diagnosis.get('disease_name'),
                'risk':     diagnosis.get('disease_risk'),
                'evidence': diagnosis.get('evidence'),
            }
            result['advisory'] = advisory
        except Exception:
            pass

    return JSONResponse(content=result)


def _overview_crops() -> list[str]:
    """Active crop list from DB — no hardcoded values."""
    try:
        return get_crop_list()
    except Exception:
        return []

def _overview_area(crop: str) -> float:
    """Typical farm area for this crop from DB."""
    try:
        areas = get_crop_areas()
        return areas.get(crop, 2.3)
    except Exception:
        return 2.3


def _all_crops_overview(predictor, year: int) -> dict:
    """Return ML yield estimates for every active crop from DB — no hardcoded list."""
    crops = _overview_crops()
    entries = []
    for crop in crops:
        area = _overview_area(crop)
        try:
            res  = _predict_compat(predictor, crop=crop, region='Ashanti', area_ha=area, year=year)
            pred = res.get('prediction', {})
            entries.append({
                'crop': crop,
                'region': 'Ghana (National Avg.)',
                'prediction': {
                    'crop':                      crop,
                    'region':                    'Ghana (National Avg.)',
                    'predicted_yield_kg_per_ha': pred.get('predicted_yield_kg_per_ha', 0),
                    'adjusted_yield_kg_per_ha':  pred.get('adjusted_yield_kg_per_ha', 0),
                    'predicted_production_tonnes': pred.get('predicted_production_tonnes', 0),
                    'area_hectares':             area,
                    'confidence_interval_lower': pred.get('confidence_interval_lower', 0),
                    'confidence_interval_upper': pred.get('confidence_interval_upper', 0),
                    'model_r2_score':            pred.get('model_r2_score', 0),
                    'disease_assessment':        pred.get('disease_assessment', {}),
                },
            })
        except Exception:
            pass

    total = len(entries)
    avg_yield = (
        sum(e['prediction']['predicted_yield_kg_per_ha'] for e in entries) / total
        if total else 0
    )
    total_prod = sum(e['prediction']['predicted_production_tonnes'] for e in entries)

    return {
        'status': 'success',
        'query': {'crop': None, 'region': None, 'district': None, 'year': year},
        'summary': {
            'total_entries': total,
            'average_yield_kg_per_ha': round(avg_yield, 1),
            'total_predicted_production_tonnes': round(total_prod, 1),
        },
        'entries': entries,
    }


_MAJOR_REGIONS = [
    'Ashanti', 'Northern', 'Western', 'Brong Ahafo',
    'Upper East', 'Eastern', 'Central', 'Volta', 'Upper West',
]


@app.post('/api/buyer-predict')
def buyer_predict(payload: BuyerForecastRequest):
    if AgriGuardPredictor is None:
        raise HTTPException(status_code=500, detail='predictor_unavailable')

    try:
        predictor = _load_predictor()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'model_load_failed: {e}')

    year = payload.year or datetime.datetime.now().year

    # No filter → national overview for all active crops
    if payload.crop is None and payload.region is None and payload.district is None:
        try:
            return JSONResponse(content=_all_crops_overview(predictor, year))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f'overview_failed: {e}')

    entries = []

    if payload.crop and payload.region:
        try:
            pred = _predict_compat(predictor, payload.crop, payload.region,
                                   _overview_area(payload.crop), year, payload.district)
            entries.append({'crop': payload.crop, 'region': payload.region,
                            'district': payload.district or '',
                            'prediction': pred['prediction']})
        except Exception:
            pass

    elif payload.crop:
        # Crop only → predict across all major regions
        for region in _MAJOR_REGIONS:
            try:
                pred = _predict_compat(predictor, payload.crop, region,
                                       _overview_area(payload.crop), year)
                entries.append({'crop': payload.crop, 'region': region,
                                'prediction': pred['prediction']})
            except Exception:
                pass

    elif payload.region:
        # Region only → all active crops in that region
        for crop in _overview_crops():
            try:
                pred = _predict_compat(predictor, crop, payload.region,
                                       _overview_area(crop), year)
                entries.append({'crop': crop, 'region': payload.region,
                                'prediction': pred['prediction']})
            except Exception:
                pass

    avg_yield  = (sum(e['prediction'].get('predicted_yield_kg_per_ha', 0) for e in entries) / len(entries)
                  if entries else 0)
    total_prod = sum(e['prediction'].get('predicted_production_tonnes', 0) for e in entries)

    return JSONResponse(content={
        'status': 'success',
        'query':  {'crop': payload.crop, 'region': payload.region,
                   'district': payload.district, 'year': year},
        'summary': {
            'total_entries':                     max(len(entries), 1),
            'average_yield_kg_per_ha':           round(float(avg_yield), 1),
            'total_predicted_production_tonnes': round(float(total_prod), 1),
        },
        'entries': entries,
    })


@app.post('/api/diagnose-disease')
def diagnose_disease(payload: TextDiagnoseRequest):
    """Text-based disease diagnosis using the Advisory Engine heuristics."""
    if _advisory_engine is None:
        raise HTTPException(status_code=500, detail='advisory_engine_unavailable')

    diagnosis = _advisory_engine.diagnose(
        crop=payload.crop,
        region=payload.region,
        symptoms=payload.symptoms,
        observed_disease=payload.observed_disease,
        weather=payload.weather_record,
        quality_score=payload.quality_score,
    )

    advisory = _advisory_engine.generate_advisory(
        crop=payload.crop,
        region=payload.region,
        disease_risk=diagnosis['disease_risk'],
        weather_risk=diagnosis.get('weather_risk', 0.0),
        quality_score=payload.quality_score,
        treatment=diagnosis.get('treatment', ''),
        prevention=diagnosis.get('prevention', ''),
    )

    return JSONResponse(content={
        'status': 'success',
        'diagnosis': {
            'disease':                  diagnosis.get('disease_name'),
            'risk':                     diagnosis.get('disease_risk'),
            'weather_risk':             diagnosis.get('weather_risk'),
            'yield_factor':             diagnosis.get('yield_factor'),
            'evidence':                 diagnosis.get('evidence'),
            'treatment':                diagnosis.get('treatment'),
            'prevention':               diagnosis.get('prevention'),
            'common_diseases_for_crop': diagnosis.get('common_diseases_for_crop'),
            'quality_note':             diagnosis.get('quality_note'),
        },
        'advisory': advisory,
    })


@app.post('/api/diagnose-disease-image')
async def diagnose_disease_image(
    image: UploadFile = File(None),
    stated_crop: str = Form(None),
):
    if infer_image is None or load_inference_assets is None:
        raise HTTPException(status_code=500, detail='disease_model_unavailable')

    assets = get_disease_model_assets()
    if assets is None:
        raise HTTPException(status_code=500, detail='disease_model_load_failed')

    save_path = None
    try:
        if image is not None:
            suffix = os.path.splitext(image.filename or 'uploaded.png')[1] or '.png'
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=os.getcwd()) as tmp:
                contents = await image.read()
                tmp.write(contents)
                save_path = tmp.name
        else:
            raise HTTPException(status_code=400, detail='missing_file')

        predicted_label, confidence_pct, probabilities = infer_image(save_path, assets)
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f'inference_failed: {e}')
    finally:
        if save_path and os.path.exists(save_path):
            try:
                os.remove(save_path)
            except Exception:
                pass

    class_names = assets.get('class_names', [])

    # ── Step 1: Plant / crop identification ───────────────────────────────────
    # Aggregate softmax probabilities for every class that belongs to the same
    # crop.  The crop with the highest total probability is the identified plant.
    CROP_DISPLAY = {
        'Apple': 'Apple',
        'Blueberry': 'Blueberry',
        'Cherry_(including_sour)': 'Cherry',
        'Corn_(maize)': 'Corn (Maize)',
        'Grape': 'Grape',
        'Orange': 'Orange',
        'Peach': 'Peach',
        'Pepper,_bell': 'Bell Pepper',
        'Potato': 'Potato',
        'Raspberry': 'Raspberry',
        'Soybean': 'Soybean',
        'Squash': 'Squash',
        'Strawberry': 'Strawberry',
        'Tomato': 'Tomato',
    }
    SUPPORTED_CROPS = list(CROP_DISPLAY.values())

    crop_probs: dict = {}
    for idx, prob in enumerate(probabilities):
        raw_name = class_names[idx] if idx < len(class_names) else ''
        crop_key = raw_name.split('___')[0] if '___' in raw_name else raw_name
        crop_probs[crop_key] = crop_probs.get(crop_key, 0.0) + float(prob)

    # Sort crops by aggregated probability
    sorted_crops = sorted(crop_probs.items(), key=lambda x: -x[1])
    best_crop_key, best_crop_prob = sorted_crops[0] if sorted_crops else ('', 0.0)
    identified_crop_display = CROP_DISPLAY.get(best_crop_key,
                                                best_crop_key.replace('_', ' '))
    identified_crop_confidence = round(best_crop_prob * 100, 1)

    # Consider the plant "identified" when ≥60 % of probability mass falls on
    # one crop family.  Below that the image is likely outside the training set.
    plant_identified = identified_crop_confidence >= 60.0

    # ── Trust the farmer's stated crop ────────────────────────────────────────
    # Real-world phone photos rarely match the clean lab images the model was
    # trained on. If the farmer already selected their crop, accept it and
    # proceed with disease diagnosis — they know what they planted.
    stated_crop_override = False
    if stated_crop and not plant_identified:
        _stated_lower = stated_crop.strip().lower()
        _crop_aliases = {
            'tomato': 'Tomato', 'corn/maize': 'Corn (Maize)', 'corn': 'Corn (Maize)',
            'maize': 'Corn (Maize)', 'potato': 'Potato', 'bell pepper': 'Bell Pepper',
            'pepper': 'Bell Pepper', 'soybean': 'Soybean', 'apple': 'Apple',
            'grape': 'Grape', 'strawberry': 'Strawberry', 'peach': 'Peach',
            'cherry': 'Cherry', 'squash': 'Squash', 'raspberry': 'Raspberry',
            'blueberry': 'Blueberry', 'orange': 'Orange',
        }
        identified_crop_display = _crop_aliases.get(_stated_lower, stated_crop.strip().title())
        plant_identified = True
        stated_crop_override = True

    # Top-3 crop candidates (for the UI)
    crop_candidates = [
        {
            'crop_key': k,
            'crop_display': CROP_DISPLAY.get(k, k.replace('_', ' ')),
            'confidence': round(v * 100, 1),
        }
        for k, v in sorted_crops[:3]
    ]

    # ── Step 2: Disease confidence level ──────────────────────────────────────
    if confidence_pct >= 80:
        confidence_level = 'high'
    elif confidence_pct >= 50:
        confidence_level = 'medium'
    else:
        confidence_level = 'low'

    # ── Top-3 disease alternatives ────────────────────────────────────────────
    # Filter alternatives to only show diseases matching the identified crop
    _crop_filter = identified_crop_display.lower().split('(')[0].strip()
    top3_all = sorted(enumerate(probabilities), key=lambda x: -x[1])
    # Try crop-filtered top3 first; fall back to global top3 if not enough
    top3_filtered = [
        (i, prob) for i, prob in top3_all
        if _crop_filter in (class_names[i] if i < len(class_names) else '').lower().replace('_', ' ')
    ][:3]
    top3 = top3_filtered if len(top3_filtered) >= 1 else top3_all[:3]

    alternatives = [
        {
            'label': class_names[i] if i < len(class_names) else str(i),
            'display': (clean_disease_label(class_names[i]) if clean_disease_label and i < len(class_names) else str(i)),
            'confidence': round(prob * 100, 1),
        }
        for i, prob in top3
    ]

    # Re-pick predicted_label from filtered alternatives when farmer stated crop
    if stated_crop_override and top3_filtered:
        best_filtered_idx = top3_filtered[0][0]
        predicted_label = class_names[best_filtered_idx] if best_filtered_idx < len(class_names) else predicted_label
        confidence_pct = round(top3_filtered[0][1] * 100, 2)
        confidence_level = 'high' if confidence_pct >= 80 else 'medium' if confidence_pct >= 50 else 'low'

    # ── Scope / quality warning ────────────────────────────────────────────────
    scope_warning = None
    if stated_crop_override:
        scope_warning = (
            f'Low image confidence — possible causes: wet leaves after watering, '
            f'water droplets, glare, or low light. '
            f'Diagnosis is based on your selected crop ({identified_crop_display}). '
            f'For best results, photograph a dry leaf in natural daylight.'
        )
    elif not plant_identified:
        scope_warning = (
            f'Plant not recognised (best match: {identified_crop_display} at {identified_crop_confidence:.1f}%). '
            'Tip: photograph a single dry leaf close-up in good natural light — '
            'avoid wet leaves, direct sun glare, or fingers in frame.'
        )
    elif confidence_pct < 60:
        scope_warning = (
            f'Low disease confidence ({confidence_pct:.1f}%). '
            'Try a closer photo of the affected leaf area in natural daylight '
            'when the leaves are dry.'
        )

    # ── Advisory details from disease_utils (basic lookup) ───────────────────
    if get_disease_details is not None:
        details = get_disease_details(predicted_label)
    else:
        details = {
            'crop': identified_crop_display,
            'disease_name': clean_disease_label(predicted_label) if clean_disease_label else predicted_label,
            'description': 'Disease detected — consult a local agricultural expert.',
            'treatment': ['Apply appropriate fungicide or pesticide as recommended by an expert.'],
            'prevention': ['Practice crop rotation and maintain good field hygiene.'],
        }

    # ── Rich advisory from AdvisoryEngine (treatment + tips + risk) ───────────
    advisory_result = None
    rich_treatment   = ''
    rich_prevention  = ''
    disease_risk     = 0.0
    if _advisory_engine is not None and plant_identified:
        try:
            disease_name_for_engine = details.get('disease_name', predicted_label)
            crop_for_engine = identified_crop_display

            eng_diagnosis = _advisory_engine.diagnose(
                crop=crop_for_engine,
                region='Ghana',
                observed_disease=disease_name_for_engine,
            )
            disease_risk    = eng_diagnosis.get('disease_risk', confidence_pct / 100 * 0.8)
            rich_treatment  = eng_diagnosis.get('treatment', '')
            rich_prevention = eng_diagnosis.get('prevention', '')

            advisory_result = _advisory_engine.generate_advisory(
                crop=crop_for_engine,
                region='Ghana',
                disease_risk=disease_risk,
                treatment=rich_treatment,
                prevention=rich_prevention,
            )
        except Exception:
            pass

    # Use rich treatment/prevention when available, fall back to basic lookup
    final_treatment  = rich_treatment  or details.get('treatment', [])
    final_prevention = rich_prevention or details.get('prevention', [])

    # ── Crop mismatch check ────────────────────────────────────────────────────
    crop_mismatch = False
    mismatch_message = None
    if stated_crop and plant_identified:
        stated_norm    = stated_crop.strip().lower()
        identified_norm = identified_crop_display.lower()
        if stated_norm not in identified_norm and identified_norm not in stated_norm:
            crop_mismatch = True
            mismatch_message = (
                f'You selected "{stated_crop}" but the model detected '
                f'"{identified_crop_display}" ({identified_crop_confidence:.0f}% confidence). '
                'Results may not be accurate. Try a clearer close-up photo of the leaf, '
                'or consult a local agronomist.'
            )

    return {
        'status': 'success',
        # ── Plant identification ───────────────────────────────────────────────
        'plant_identified':             plant_identified,
        'identified_crop':              identified_crop_display,
        'identified_crop_confidence':   identified_crop_confidence,
        'crop_candidates':              crop_candidates,
        'stated_crop':                  stated_crop,
        'crop_mismatch':                crop_mismatch,
        'mismatch_message':             mismatch_message,
        # ── Disease diagnosis ─────────────────────────────────────────────────
        'disease_label':    predicted_label,
        'confidence_score': round(confidence_pct, 2),
        'confidence_level': confidence_level,
        'disease_risk':     round(disease_risk, 3),
        'alternatives':     alternatives,
        'scope_warning':    scope_warning,
        'supported_crops':  SUPPORTED_CROPS,
        'source':           'image_model',
        # ── Disease info ──────────────────────────────────────────────────────
        'crop':             details.get('crop', identified_crop_display),
        'disease_name':     details.get('disease_name', predicted_label),
        'disease_category': details.get('disease_category', ''),
        'description':      details.get('description', ''),
        'treatment':        final_treatment,
        'prevention':       final_prevention,
        # ── Advisory (tips, summary, risk level) ──────────────────────────────
        'advisory':         advisory_result,
    }


RETRAIN_LOG_FILE  = os.path.join('farmer_submissions', 'retrain_log.json')
MIN_SUBMISSIONS_FOR_RETRAIN = 5


def _background_retrain():
    """Run model retraining in a background thread after a new submission milestone."""
    try:
        import importlib, sys as _sys
        _sys.path.insert(0, _PS_DIR)
        import compare_models as _cm
        importlib.reload(_cm)
        baseline_m, advanced_m, _, outcome = _cm.run_comparison(use_db=True)
        if outcome.get('production_updated'):
            print(
                f'[RETRAIN] Production model UPDATED '
                f'(R²: {outcome["prev_r2"]:.4f} → {outcome["new_r2"]:.4f}, '
                f'MAE: {outcome["prev_mae"]} → {outcome["new_mae"]} kg/ha)'
            )
        else:
            print(
                f'[RETRAIN] Production model KEPT — retrain R²={outcome["new_r2"]:.4f} '
                f'did not beat current R²={outcome["prev_r2"]:.4f}. best_model.joblib unchanged.'
            )
    except Exception as _e:
        import traceback as _tb
        print(f'[RETRAIN] Auto-retrain failed: {_e}')
        _tb.print_exc()


@app.post('/api/predict/post-harvest')
def post_harvest(payload: PostHarvestRequest):
    """Record a farmer's actual harvest and return a comparison with the model prediction."""
    year = payload.year or datetime.datetime.now().year
    actual_kg_ha = payload.actual_yield_kg / payload.area_hectares if payload.area_hectares > 0 else 0.0

    # Run model prediction for comparison if predictor is available
    predicted_kg_ha = None
    model_comparison = None
    if AgriGuardPredictor is not None:
        try:
            predictor = _load_predictor()
            pred = _predict_compat(
                predictor,
                crop=payload.crop,
                region=payload.region,
                area_ha=payload.area_hectares,
                district=payload.district,
                year=year,
            )
            inner = pred.get('prediction', pred)
            predicted_kg_ha = inner.get('predicted_yield_kg_per_ha') or inner.get('adjusted_yield_kg_per_ha')
            if predicted_kg_ha is not None:
                diff = actual_kg_ha - float(predicted_kg_ha)
                pct  = (diff / float(predicted_kg_ha) * 100) if predicted_kg_ha else 0
                model_comparison = {
                    'model_predicted_yield_kg_per_ha': round(float(predicted_kg_ha), 1),
                    'actual_yield_kg_per_ha': round(actual_kg_ha, 1),
                    'difference_kg_per_ha': round(diff, 1),
                    'difference_pct': round(pct, 1),
                    'assessment': (
                        'Above prediction' if diff > 50 else
                        'Below prediction' if diff < -50 else
                        'Close to prediction'
                    ),
                }
        except Exception:
            pass

    # Save submission to Neon database
    quantity_for_sale = payload.quantity_available_kg or payload.actual_yield_kg
    submission = {
        'farmer_id':              payload.farmer_id,
        'crop':                   payload.crop,
        'region':                 payload.region,
        'district':               payload.district,
        'town':                   payload.town,
        'phone':                  payload.phone if payload.consent_market else None,
        'area_hectares':          payload.area_hectares,
        'actual_yield_kg':        payload.actual_yield_kg,
        'actual_yield_kg_per_ha': round(actual_kg_ha, 1),
        'quantity_available_kg':  quantity_for_sale,
        'price_per_kg_ghs':       payload.price_per_kg_ghs,
        'quality_score':          payload.quality_score,
        'notes':                  payload.notes,
        'year':                   year,
        'consent_market':         payload.consent_market,
        'consent_training':       payload.consent_training,
    }
    try:
        saved = db_insert(submission)
        submission['submitted_at'] = saved.get('submitted_at', datetime.datetime.now().isoformat())
        # Auto-retrain every MIN_SUBMISSIONS_FOR_RETRAIN submissions
        try:
            total = count_submissions()
            if total > 0 and total % MIN_SUBMISSIONS_FOR_RETRAIN == 0:
                print(f'[RETRAIN] Milestone reached ({total} submissions). Starting background retrain.')
                threading.Thread(target=_background_retrain, daemon=True).start()
        except Exception as _ce:
            print(f'[WARN] Could not check submission count: {_ce}')
    except Exception as e:
        print(f'[WARN] Could not save to database: {e}')
        submission['submitted_at'] = datetime.datetime.now().isoformat()

    return JSONResponse(content={
        'status': 'success',
        'message': 'Harvest report submitted successfully. Thank you for contributing to the model.',
        'submission': submission,
        'model_comparison': model_comparison,
    })


@app.get('/api/harvest/actuals')
def harvest_actuals(
    crop: Optional[str] = None,
    region: Optional[str] = None,
    district: Optional[str] = None,
    year: Optional[int] = None,
):
    """Return real farmer harvest submissions for buyers — ground truth, not ML predictions."""
    try:
        records = query_actuals(crop=crop, region=region, district=district, year=year)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')

    entries = []
    for rec in records:
        yield_kg_ha  = float(rec.get('actual_yield_kg_per_ha') or 0)
        area_ha      = float(rec.get('area_hectares') or 0)
        prod_t       = round(float(rec.get('actual_yield_kg') or 0) / 1000, 3)
        qty_for_sale = float(rec.get('quantity_available_kg') or rec.get('actual_yield_kg') or 0)
        submitted_at = rec.get('submitted_at')
        submitted_str = submitted_at.isoformat() if hasattr(submitted_at, 'isoformat') else str(submitted_at or '')
        entries.append({
            'crop':                  rec.get('crop', ''),
            'region':                rec.get('region', ''),
            'district':              rec.get('district') or '',
            'town':                  rec.get('town') or '',
            'phone':                 rec.get('phone') or '',
            'price_per_kg_ghs':      rec.get('price_per_kg_ghs'),
            'quantity_available_kg': qty_for_sale,
            'area_hectares':         area_ha,
            'submitted_at':          submitted_str,
            'farmer_id':             rec.get('farmer_id'),
            'source':                'farmer_submission',
            'prediction': {
                'crop':                        rec.get('crop', ''),
                'region':                      rec.get('region', ''),
                'district':                    rec.get('district') or '',
                'predicted_yield_kg_per_ha':   yield_kg_ha,
                'adjusted_yield_kg_per_ha':    yield_kg_ha,
                'predicted_production_tonnes': prod_t,
                'area_hectares':               area_ha,
                'confidence_interval_lower':   yield_kg_ha,
                'confidence_interval_upper':   yield_kg_ha,
                'model_r2_score':              0,
                'year':                        rec.get('year'),
                'quality_score':               rec.get('quality_score'),
                'notes':                       rec.get('notes'),
            },
        })

    total      = len(entries)
    avg_yield  = sum(e['prediction']['predicted_yield_kg_per_ha'] for e in entries) / total if total else 0
    total_prod = sum(e['prediction']['predicted_production_tonnes'] for e in entries)
    total_qty  = sum(e.get('quantity_available_kg') or 0 for e in entries)
    prices     = [e['price_per_kg_ghs'] for e in entries if e.get('price_per_kg_ghs') is not None]
    min_price  = min(prices) if prices else None
    max_price  = max(prices) if prices else None
    avg_price  = round(sum(prices) / len(prices), 2) if prices else None

    return JSONResponse(content={
        'status':  'success',
        'query':   {'crop': crop, 'region': region, 'district': district, 'year': year},
        'summary': {
            'total_entries':                     total,
            'average_yield_kg_per_ha':           round(avg_yield, 1),
            'total_predicted_production_tonnes': round(total_prod, 3),
            'total_actual_production_tonnes':    round(total_prod, 3),
            'total_quantity_kg':                 round(total_qty, 1),
            'min_price_ghs':                     min_price,
            'max_price_ghs':                     max_price,
            'avg_price_ghs':                     avg_price,
        },
        'entries': entries,
        'message': 'No harvest reports submitted yet.' if total == 0 else None,
    })


@app.get('/api/harvest/my-submissions')
def my_submissions(farmer_id: str):
    """Return a farmer's own harvest submissions (excluding hidden ones)."""
    try:
        records = query_my_submissions(farmer_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')

    submissions = []
    for rec in records:
        submitted_at = rec.get('submitted_at')
        submitted_str = submitted_at.isoformat() if hasattr(submitted_at, 'isoformat') else str(submitted_at or '')
        submissions.append({**rec, 'submitted_at': submitted_str})

    return JSONResponse(content={'status': 'success', 'submissions': submissions})


@app.delete('/api/harvest/hide')
def hide_submission_endpoint(farmer_id: str, submitted_at: str):
    """
    Soft-delete: mark a submission as hidden so the farmer no longer sees it,
    but keep it in the database for model retraining.
    """
    try:
        matched = db_hide(farmer_id, submitted_at)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')

    if not matched:
        raise HTTPException(status_code=404, detail='submission_not_found')

    return JSONResponse(content={'status': 'success', 'message': 'Submission removed from your list.'})


# ── Auth request schemas ───────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    id: Optional[str] = Field(None)
    name: str = Field(..., example='Kofi Mensah')
    email: str = Field(..., example='kofi@example.com')
    phone: str = Field(..., example='024 123 4567')
    password: str = Field(..., min_length=6)
    role: str = Field(default='farmer', example='farmer')
    region: Optional[str] = Field(None)
    district: Optional[str] = Field(None)
    farm_size_ha: Optional[float] = Field(None)

class LoginRequest(BaseModel):
    email: str
    password: str

class DiaryEntryRequest(BaseModel):
    farmer_id: str = Field(..., example='AGRI-123')
    crop: str = Field(..., example='Maize')
    region: str = Field(..., example='Ashanti')
    district: Optional[str] = Field(None)
    planting_date: Optional[str] = Field(None, example='2026-04-01')
    record_date: Optional[str] = Field(None, example='2026-06-27')
    growth_stage: Optional[str] = Field(None, example='Vegetative Growth')
    temp_min_c: Optional[float] = Field(None, example=22.0)
    temp_max_c: Optional[float] = Field(None, example=31.0)
    rainfall_mm: Optional[float] = Field(None, example=12.5)
    fertilizer_applied: bool = Field(default=False)
    fertilizer_type: Optional[str] = Field(None)
    fertilizer_kg_ha: Optional[float] = Field(None)
    pest_observed: bool = Field(default=False)
    pest_description: Optional[str] = Field(None)
    disease_observed: bool = Field(default=False)
    disease_description: Optional[str] = Field(None)
    irrigation_applied: bool = Field(default=False)
    notes: Optional[str] = Field(None)


# ── Auth endpoints ─────────────────────────────────────────────────────────────

@app.post('/api/auth/register')
def register(payload: RegisterRequest):
    import uuid
    user_id = payload.id or f'AGRI-{datetime.datetime.now().strftime("%Y%m%d%H%M%S%f")}'
    try:
        user = create_user({
            'id': user_id,
            'name': payload.name.strip(),
            'email': payload.email.strip().lower(),
            'phone': payload.phone.strip(),
            'password': payload.password,
            'role': payload.role,
            'region': payload.region,
            'district': payload.district,
            'farm_size_ha': payload.farm_size_ha,
        })
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'registration_failed: {e}')
    return JSONResponse(content={'status': 'success', 'user': _serialise(user)})


@app.post('/api/auth/login')
def login(payload: LoginRequest):
    # Admin shortcut
    if payload.email.strip().lower() == ADMIN_EMAIL.lower() and payload.password == ADMIN_PASSWORD:
        return JSONResponse(content={
            'status': 'success',
            'user': {
                'id': 'admin',
                'name': 'Admin',
                'email': ADMIN_EMAIL,
                'phone': '',
                'role': 'admin',
                'region': None,
                'district': None,
                'farm_size_ha': None,
            },
        })
    user = find_user_by_email(payload.email.strip(), payload.password)
    if user is None:
        raise HTTPException(status_code=401, detail='invalid_credentials')
    return JSONResponse(content={'status': 'success', 'user': _serialise(user)})


class ResetPasswordRequest(BaseModel):
    email:        str = Field(..., example='farmer@example.com')
    name:         str = Field(..., example='Kwame Mensah')
    new_password: str = Field(..., example='newpass123')

@app.post('/api/auth/reset-password')
def reset_password(payload: ResetPasswordRequest):
    """
    Self-service password reset verified by email + registered full name.
    No email sending required — name acts as the second factor.
    """
    if not payload.new_password or len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail='New password must be at least 6 characters.')
    try:
        user_id = verify_user_for_reset(payload.email, payload.name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    if not user_id:
        raise HTTPException(
            status_code=400,
            detail='No account found with that email and name. '
                   'Make sure you enter your name exactly as you registered.',
        )
    try:
        update_user_password(user_id, payload.new_password)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={
        'status': 'success',
        'message': 'Password updated successfully. You can now log in with your new password.',
    })


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(..., description='Google ID token from the client')

@app.post('/api/auth/google')
def google_auth(payload: GoogleAuthRequest):
    """
    Verify a Google ID token and return (or create) the matching AgriGuard account.
    Returns {status, user, is_new}.  New accounts default to role='farmer'; the
    client should prompt the user to pick a role and call PATCH /api/auth/role.
    """
    import urllib.request as _req
    import json as _json
    import urllib.parse as _parse

    # Verify token with Google's tokeninfo endpoint
    try:
        url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + _parse.quote(payload.id_token, safe='')
        with _req.urlopen(url, timeout=10) as resp:
            info = _json.loads(resp.read())
    except Exception as e:
        raise HTTPException(status_code=401, detail=f'google_token_invalid: {e}')

    if info.get('error_description') or not info.get('email_verified'):
        raise HTTPException(status_code=401, detail='google_token_invalid')

    google_id = info.get('sub')
    email     = info.get('email', '')
    name      = info.get('name') or email.split('@')[0]

    if not google_id or not email:
        raise HTTPException(status_code=401, detail='google_token_missing_claims')

    try:
        user, is_new = find_or_create_google_user(google_id, email, name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')

    return JSONResponse(content={
        'status': 'success',
        'user':   _serialise(user),
        'is_new': is_new,
    })


@app.patch('/api/auth/role')
def set_role(user_id: str, role: str):
    """Let a user update their own role (farmer ↔ buyer). Used after Google sign-in."""
    try:
        update_user_role(user_id, role)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success'})


@app.delete('/api/auth/delete-account')
def delete_account(user_id: str):
    """
    Soft-delete user and all their data.
    Data (submissions, diary) is kept hidden in DB for model retraining.
    """
    try:
        soft_delete_user(user_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={
        'status': 'success',
        'message': 'Your account and all associated data have been removed from AgriGuard. '
                   'Anonymised records may be retained to improve crop predictions.',
    })


# ── Farm diary endpoints ────────────────────────────────────────────────────────

@app.post('/api/diary')
def submit_diary(payload: DiaryEntryRequest):
    """Log a daily farm activity entry — feeds the in-season prediction model."""
    rec = {
        'farmer_id':          payload.farmer_id,
        'crop':               payload.crop,
        'region':             payload.region,
        'district':           payload.district,
        'planting_date':      payload.planting_date,
        'record_date':        payload.record_date or datetime.date.today().isoformat(),
        'growth_stage':       payload.growth_stage,
        'temp_min_c':         payload.temp_min_c,
        'temp_max_c':         payload.temp_max_c,
        'rainfall_mm':        payload.rainfall_mm,
        'fertilizer_applied': payload.fertilizer_applied,
        'fertilizer_type':    payload.fertilizer_type,
        'fertilizer_kg_ha':   payload.fertilizer_kg_ha,
        'pest_observed':      payload.pest_observed,
        'pest_description':   payload.pest_description,
        'disease_observed':   payload.disease_observed,
        'disease_description':payload.disease_description,
        'irrigation_applied': payload.irrigation_applied,
        'notes':              payload.notes,
    }
    try:
        saved = insert_diary_entry(rec)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'entry': _serialise(saved)})


@app.get('/api/diary/my-entries')
def my_diary(farmer_id: str):
    try:
        rows = query_my_diary(farmer_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'entries': [_serialise(r) for r in rows]})


@app.delete('/api/diary/hide')
def hide_diary(farmer_id: str, entry_id: int):
    try:
        matched = hide_diary_entry(farmer_id, entry_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    if not matched:
        raise HTTPException(status_code=404, detail='entry_not_found')
    return JSONResponse(content={'status': 'success'})


@app.get('/api/diary/in-season-forecast')
def in_season_forecast(farmer_id: str, crop: str, planting_date: str, area_hectares: float = 1.0):
    """
    Use accumulated daily diary entries to predict final yield before harvest.
    More diary entries → better prediction accuracy.
    """
    try:
        entries = query_diary_for_season(farmer_id, crop, planting_date)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')

    if not entries:
        raise HTTPException(status_code=404, detail='no_diary_entries_for_this_season')

    # Compute accumulated seasonal features
    days_logged      = len(entries)
    cum_rainfall     = sum(float(e.get('rainfall_mm') or 0) for e in entries)
    fertilizer_count = sum(1 for e in entries if e.get('fertilizer_applied'))
    pest_events      = sum(1 for e in entries if e.get('pest_observed'))
    disease_events   = sum(1 for e in entries if e.get('disease_observed'))
    irrigation_days  = sum(1 for e in entries if e.get('irrigation_applied'))

    # Growing Degree Days (GDD) — base temp 10°C for most tropical crops
    gdd = 0.0
    for e in entries:
        tmax = e.get('temp_max_c') or 30
        tmin = e.get('temp_min_c') or 22
        gdd += max(0, (tmax + tmin) / 2 - 10)

    latest_stage = entries[-1].get('growth_stage') or 'Unknown'

    # Base prediction from ML model, adjusted by diary factors
    base_yield = 0.0
    if AgriGuardPredictor is not None:
        try:
            predictor = _load_predictor()
            ml = _predict_compat(
                predictor,
                crop=crop,
                region=entries[0].get('region', 'Ashanti'),
                area_ha=area_hectares,
            ).get('prediction', {})
            base_yield = float(ml.get('predicted_yield_kg_per_ha') or 0)
        except Exception:
            base_yield = 2000.0

    # Adjustment factors based on diary data
    adjustment = 1.0
    adjustment += fertilizer_count * 0.03       # each fertilizer application +3%
    adjustment -= pest_events * 0.04            # each pest event -4%
    adjustment -= disease_events * 0.05         # each disease event -5%
    adjustment += irrigation_days * 0.02        # each irrigation day +2%
    if cum_rainfall > 400:
        adjustment += 0.05
    elif cum_rainfall < 100:
        adjustment -= 0.10

    adjusted_yield = round(base_yield * max(0.3, min(2.0, adjustment)), 1)
    total_kg       = round(adjusted_yield * area_hectares, 1)

    # Estimate days to harvest using GDD thresholds per crop
    GDD_TO_HARVEST = {
        'Maize': 1200, 'Rice': 1400, 'Tomato': 900, 'Pepper': 1100,
        'Cassava': 3000, 'Yam': 2500, 'Groundnut': 1300, 'Soybean': 1300,
        'Cowpea': 1000, 'Millet': 1000, 'Sorghum': 1200,
    }
    gdd_needed  = GDD_TO_HARVEST.get(crop, 1200)
    gdd_per_day = gdd / days_logged if days_logged > 0 else 15
    gdd_remaining = max(0, gdd_needed - gdd)
    days_remaining = round(gdd_remaining / gdd_per_day) if gdd_per_day > 0 else None
    harvest_date_est = None
    if days_remaining is not None:
        from datetime import date, timedelta
        harvest_date_est = (date.today() + timedelta(days=days_remaining)).isoformat()

    confidence = min(95, 40 + days_logged * 2)  # confidence grows with more diary entries

    return JSONResponse(content={
        'status': 'success',
        'crop': crop, 'region': entries[0].get('region'),
        'planting_date': planting_date,
        'days_logged': days_logged,
        'current_stage': latest_stage,
        'accumulated': {
            'gdd': round(gdd, 1),
            'rainfall_mm': round(cum_rainfall, 1),
            'fertilizer_applications': fertilizer_count,
            'pest_events': pest_events,
            'disease_events': disease_events,
            'irrigation_days': irrigation_days,
        },
        'forecast': {
            'predicted_yield_kg_per_ha': adjusted_yield,
            'total_predicted_kg': total_kg,
            'days_to_harvest': days_remaining,
            'estimated_harvest_date': harvest_date_est,
            'confidence_pct': confidence,
            'note': f'Based on {days_logged} diary entries. Add more daily logs to improve accuracy.',
        },
    })


# ── Admin endpoints ────────────────────────────────────────────────────────────

def _check_admin(admin_key: str):
    if admin_key != ADMIN_PASSWORD:
        raise HTTPException(status_code=403, detail='admin_access_required')


@app.post('/api/admin/reset-password')
def admin_reset_password(email: str, new_password: str, admin_key: str):
    _check_admin(admin_key)
    import hashlib
    try:
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute(
                "UPDATE users SET password_hash=%s WHERE LOWER(email)=LOWER(%s)",
                (hashlib.sha256(new_password.encode()).hexdigest(), email)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail='user_not_found')
        return {'status': 'success', 'message': f'Password reset for {email}'}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get('/api/admin/stats')
def admin_stats_endpoint(admin_key: str):
    _check_admin(admin_key)
    try:
        stats = admin_stats()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'stats': stats})


@app.get('/api/admin/users')
def admin_users_endpoint(admin_key: str, include_deleted: bool = True):
    _check_admin(admin_key)
    try:
        users = admin_all_users(include_deleted)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'users': [_serialise(u) for u in users]})


@app.get('/api/admin/submissions')
def admin_submissions_endpoint(admin_key: str, include_hidden: bool = True):
    _check_admin(admin_key)
    try:
        rows = admin_all_submissions(include_hidden)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'submissions': [_serialise(r) for r in rows]})


@app.get('/api/admin/diary')
def admin_diary_endpoint(admin_key: str, include_hidden: bool = True):
    _check_admin(admin_key)
    try:
        rows = admin_all_diary(include_hidden)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'entries': [_serialise(r) for r in rows]})


# ── Continuous-learning retrain endpoint ───────────────────────────────────────

@app.post('/api/admin/retrain')
def admin_retrain(admin_key: str):
    """
    Retrain both Baseline (Random Forest) and Advanced (Gradient Boosting) models
    using the full dataset: historical CSV + farmer harvest submissions + farm diary
    entries from the DB.  The best model is saved as best_model.joblib and the API
    serves predictions from it on the next call.
    """
    _check_admin(admin_key)

    try:
        import importlib, sys as _sys
        _sys.path.insert(0, _PS_DIR)
        import compare_models as _cm
        importlib.reload(_cm)  # pick up any source changes
    except ImportError as e:
        raise HTTPException(status_code=500, detail=f'compare_models_not_found: {e}')

    try:
        baseline_m, advanced_m, features, outcome = _cm.run_comparison(use_db=True)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        import traceback as _tb
        _tb.print_exc()
        raise HTTPException(status_code=500, detail=f'retrain_failed: {e}')

    production_updated = outcome.get('production_updated', False)
    message = (
        f'Production model UPDATED: R² improved from {outcome["prev_r2"]} to {outcome["new_r2"]}.'
        if production_updated
        else f'Retrain complete but production model KEPT: new R²={outcome["new_r2"]} '
             f'did not beat current R²={outcome["prev_r2"]}. best_model.joblib unchanged.'
    )

    return JSONResponse(content={
        'status':             'success',
        'production_updated': production_updated,
        'message':            message,
        'retrained_model': {
            'model':          outcome.get('new_model_type'),
            'r2_test':        outcome.get('new_r2'),
            'mae_test_kg_ha': outcome.get('new_mae'),
        },
        'production_model': {
            'model':          outcome.get('prev_model_type'),
            'r2_test':        outcome.get('prev_r2'),
            'mae_test_kg_ha': outcome.get('prev_mae'),
            'trained_at':     outcome.get('prev_trained_at'),
        },
        'baseline': {
            'model':          'RandomForestRegressor',
            'r2_test':        round(baseline_m.get('r2_test', 0), 4),
            'mae_test_kg_ha': round(baseline_m.get('mae_test', 0), 1),
            'n_train':        baseline_m.get('n_train', 0),
        },
        'advanced': {
            'model':          'GradientBoostingRegressor',
            'r2_test':        round(advanced_m.get('r2_test', 0), 4),
            'mae_test_kg_ha': round(advanced_m.get('mae_test', 0), 1),
            'n_train':        advanced_m.get('n_train', 0),
        },
        'features': features,
    })


@app.get('/api/admin/retrain-history')
def retrain_history(admin_key: str):
    """Return the comparison report from the last retrain run."""
    _check_admin(admin_key)
    log_path = os.path.join(_PS_DIR, 'models', 'comparison_report.json')
    if not os.path.exists(log_path):
        return JSONResponse(content={'status': 'success', 'history': []})
    import json as _json
    with open(log_path) as f:
        report = _json.load(f)
    return JSONResponse(content={'status': 'success', 'history': [report]})


@app.get('/api/admin/model-comparison')
def model_comparison(admin_key: str):
    """
    Return the full baseline vs advanced model comparison report including
    metrics, feature importances, and hyperparameter rationale.
    """
    _check_admin(admin_key)
    report_path = os.path.join(_PS_DIR, 'models', 'comparison_report.json')
    if not os.path.exists(report_path):
        raise HTTPException(
            status_code=404,
            detail='No comparison report found. Run POST /api/admin/retrain first.'
        )
    import json as _json
    with open(report_path) as f:
        report = _json.load(f)
    return JSONResponse(content={'status': 'success', 'comparison': report})


# ── Buyer activity logging ──────────────────────────────────────────────────────

class BuyerActivityRequest(BaseModel):
    buyer_id: str
    action:   str = Field(..., description="browse | search | select")
    screen:   Optional[str] = None
    crop:     Optional[str] = None
    region:   Optional[str] = None
    district: Optional[str] = None
    item_id:  Optional[str] = None
    query:    Optional[str] = None
    details:  Optional[dict] = None


@app.post('/api/buyer/activity')
def log_activity(payload: BuyerActivityRequest):
    """Fire-and-forget — logs what a buyer browses, searches and selects."""
    try:
        log_buyer_activity({
            'buyer_id': payload.buyer_id,
            'action':   payload.action,
            'screen':   payload.screen,
            'crop':     payload.crop,
            'region':   payload.region,
            'district': payload.district,
            'item_id':  payload.item_id,
            'query':    payload.query,
            'details':  payload.details,
        })
    except Exception as e:
        print(f'[WARN] Could not log buyer activity: {e}')
    return JSONResponse(content={'status': 'ok'})


@app.get('/api/buyer/my-activity')
def my_activity(buyer_id: str):
    """Return this buyer's own browsing/search/select history."""
    try:
        rows = query_my_activity(buyer_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'activity': [_serialise(r) for r in rows]})


@app.delete('/api/buyer/activity/entry')
def delete_activity_entry_endpoint(buyer_id: str, entry_id: int):
    """Delete one specific activity entry (buyer managing own data)."""
    try:
        matched = delete_activity_entry(buyer_id, entry_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    if not matched:
        raise HTTPException(status_code=404, detail='entry_not_found')
    return JSONResponse(content={'status': 'success'})


@app.delete('/api/buyer/activity/clear')
def clear_activity_endpoint(buyer_id: str):
    """Delete ALL activity logs for this buyer."""
    try:
        count = clear_my_activity(buyer_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={'status': 'success', 'deleted': count})


class UpdateProfileRequest(BaseModel):
    user_id:  str
    name:     Optional[str] = None
    phone:    Optional[str] = None
    region:   Optional[str] = None
    district: Optional[str] = None


@app.put('/api/auth/update-profile')
def update_profile(payload: UpdateProfileRequest):
    try:
        updated = update_user_profile(payload.user_id, {
            'name':     payload.name,
            'phone':    payload.phone,
            'region':   payload.region,
            'district': payload.district,
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    if updated is None:
        raise HTTPException(status_code=404, detail='user_not_found')
    return JSONResponse(content={'status': 'success', 'user': _serialise(updated)})


@app.get('/api/admin/buyer-activity')
def admin_buyer_activity_endpoint(admin_key: str, limit: int = 500):
    _check_admin(admin_key)
    try:
        rows  = admin_buyer_activity(limit)
        stats = admin_buyer_stats()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'db_error: {e}')
    return JSONResponse(content={
        'status': 'success',
        'stats':  _serialise(stats),
        'activity': [_serialise(r) for r in rows],
    })


# ── Regional forecast (model + CSV) ───────────────────────────────────────────

# display_name, model_crop_name, fao_item, region, regional_area_share
# model_crop_name must match the canonical names in best_model.joblib label encoder
# fao_item must match the Item column in FAOSTAT_data_en_6-16-2026.csv
# region / area_share: best producing region + its share of national output
_FORECAST_PAIRS = [
    # --- Staple cereals & tubers (regional data available) ---
    ('Maize',      'Maize',    'Maize (corn)',              'ASHANTI',         0.22),
    ('Rice',       'Rice',     'Rice',                      'NORTHERN',        0.38),
    ('Cassava',    'Cassava',  'Cassava, fresh',             'ASHANTI',         0.18),
    ('Yam',        'Yam',      'Yams',                      'BRONG AHAFO',     0.25),
    ('Plantain',   'Plantain', 'Plantains and cooking bananas', 'ASHANTI',      0.20),
    ('Cocoyam',    'Cocoyam',  'Taro',                      'EASTERN',         0.20),
    ('Millet',     'Millet',   'Millet',                    'UPPER EAST',      0.42),
    ('Sorghum',    'Sorghum',  'Sorghum',                   'UPPER EAST',      0.45),
    # --- Legumes (regional data available) ---
    ('Groundnuts', 'Groundnuts', 'Groundnuts, excluding shelled', 'NORTHERN',  0.35),
    ('Cowpea',     'Cowpea',   'Cow peas, dry',             'NORTHERN',        0.40),
    ('Soybean',    'Soybean',  'Soya beans',                'BRONG AHAFO',     0.40),
    ('Beans',      'Beans',    'Beans, dry',                'ASHANTI',         0.25),
    # --- Cash crops ---
    ('Cocoa',      'Cocoa',    'Cocoa beans',               'WESTERN',         0.55),
    ('Oil Palm',   'Oil Palm', 'Oil palm fruit',            'WESTERN',         0.45),
    ('Cashew',     'Cashew',   'Cashew nuts, in shell',     'BRONG AHAFO',     0.40),
    ('Rubber',     'Rubber',   'Natural rubber in primary forms', 'WESTERN',   0.50),
    ('Cotton',     'Cotton',   'Seed cotton, unginned',     'NORTHERN',        0.60),
    ('Shea Nuts',  'Shea Nuts','Karite nuts (sheanuts)',    'UPPER WEST',      0.45),
    # --- Vegetables ---
    ('Tomatoes',   'Tomatoes', 'Tomatoes',                  'BRONG AHAFO',     0.30),
    ('Okra',       'Okra',     'Okra',                      'VOLTA',           0.25),
    ('Pepper (Green)', 'Pepper (Green)', 'Chillies and peppers, green (Capsicum spp. and Pimenta spp.)', 'ASHANTI', 0.25),
    ('Onions',     'Onions',   'Onions and shallots, dry (excluding dehydrated)', 'UPPER EAST', 0.50),
    ('Eggplant',   'Eggplant', 'Eggplants (aubergines)',    'ASHANTI',         0.25),
    # --- Fruits ---
    ('Pineapples', 'Pineapples','Pineapples',               'EASTERN',         0.45),
    ('Bananas',    'Bananas',  'Bananas',                   'ASHANTI',         0.30),
    ('Mangoes',    'Mangoes',  'Mangoes, guavas and mangosteens', 'EASTERN',   0.30),
    ('Oranges',    'Oranges',  'Oranges',                   'BRONG AHAFO',     0.35),
    ('Avocados',   'Avocados', 'Avocados',                  'EASTERN',         0.40),
    ('Papayas',    'Papayas',  'Papayas',                   'VOLTA',           0.30),
    # --- Other ---
    ('Sweet Potato','Sweet potatoes','Sweet potatoes',       'VOLTA',           0.30),
    ('Ginger',     'Ginger, raw','Ginger, raw',             'BRONG AHAFO',     0.35),
    ('Coffee',     'Coffee, green','Coffee, green',          'EASTERN',         0.45),
]

_FAO_CSV     = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'dataset', 'data', 'historical', 'FAOSTAT_data_en_6-16-2026.csv'))
_fao_df_cache = None

def _load_fao_df():
    global _fao_df_cache
    if _fao_df_cache is not None:
        return _fao_df_cache
    import pandas as pd
    df = pd.read_csv(_FAO_CSV)
    df['Year']  = pd.to_numeric(df['Year'],  errors='coerce').astype('Int64')
    df['Value'] = pd.to_numeric(df['Value'], errors='coerce')
    _fao_df_cache = df
    return df


def _fao_val(fao_df, item: str, element: str, year: int):
    rows = fao_df[(fao_df['Item'] == item) &
                  (fao_df['Element'] == element) &
                  (fao_df['Year'] == year)]
    return float(rows['Value'].iloc[0]) if not rows.empty else None


@app.get('/api/regional-forecast')
def regional_forecast_endpoint(year: Optional[int] = None):
    """
    Regional supply forecast using FAOSTAT actuals (2012-2024) + ML model (2025+).
    """
    import pandas as pd, warnings
    warnings.filterwarnings('ignore')

    try:
        fao = _load_fao_df()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'csv_error: {e}')

    fao_years   = sorted(fao['Year'].dropna().astype(int).unique().tolist())
    max_fao_yr  = max(fao_years)
    now_yr      = datetime.datetime.now().year
    if year is None:
        year = now_yr
    forecast_years = list(range(max_fao_yr + 1, 2031))

    predictor = None
    if AgriGuardPredictor is not None:
        try:
            predictor = _load_predictor()
        except Exception:
            pass

    results = []
    for display_crop, model_crop, fao_item, region_key, area_share in _FORECAST_PAIRS:
        # ── Get yield and area ──────────────────────────────────────────
        if year <= max_fao_yr:
            curr_yield = _fao_val(fao, fao_item, 'Yield', year)
            prev_yield = _fao_val(fao, fao_item, 'Yield', year - 1)
            curr_area  = (_fao_val(fao, fao_item, 'Area harvested', year) or 0) * area_share
            curr_prod  = (_fao_val(fao, fao_item, 'Production', year) or 0) * area_share
            is_model   = False
            if curr_yield is None:
                # fall back to most recent available year
                curr_yield = _fao_val(fao, fao_item, 'Yield', max_fao_yr)
                prev_yield = _fao_val(fao, fao_item, 'Yield', max_fao_yr - 1)
                curr_area  = (_fao_val(fao, fao_item, 'Area harvested', max_fao_yr) or 0) * area_share
                curr_prod  = (_fao_val(fao, fao_item, 'Production', max_fao_yr) or 0) * area_share
        else:
            # Future: use ML model, project area using recent FAOSTAT trend
            base_yield = _fao_val(fao, fao_item, 'Yield', max_fao_yr) or 0
            prev2_yield = _fao_val(fao, fao_item, 'Yield', max_fao_yr - 1) or base_yield
            base_area  = (_fao_val(fao, fao_item, 'Area harvested', max_fao_yr) or 0) * area_share

            yoy_rate = (base_yield - prev2_yield) / prev2_yield if prev2_yield > 0 else 0.0
            yrs_ahead = year - max_fao_yr
            prev_yr_ahead = yrs_ahead - 1

            if predictor:
                try:
                    # New predictor returns flat dict — no 'prediction' nesting
                    p_curr = predictor.predict_regional_aggregate(model_crop, region_key, year)
                    p_prev = predictor.predict_regional_aggregate(model_crop, region_key, year - 1)
                    _ = p_curr.get('predicted_yield_kg_per_ha')  # validate result shape
                    # Blend model signal with FAOSTAT trend for smoother extrapolation
                    curr_yield = base_yield * ((1 + yoy_rate) ** yrs_ahead)
                    prev_yield = base_yield * ((1 + yoy_rate) ** prev_yr_ahead)
                except Exception:
                    curr_yield = base_yield * ((1 + yoy_rate) ** yrs_ahead)
                    prev_yield = base_yield * ((1 + yoy_rate) ** prev_yr_ahead)
            else:
                curr_yield = base_yield * ((1 + yoy_rate) ** yrs_ahead)
                prev_yield = base_yield * ((1 + yoy_rate) ** prev_yr_ahead)

            curr_area  = base_area * ((1 + yoy_rate * 0.5) ** yrs_ahead)
            curr_prod  = curr_yield * curr_area / 1000
            is_model   = True

        if curr_yield is None:
            continue

        trend_pct = round((curr_yield - prev_yield) / prev_yield * 100, 1) if (prev_yield and prev_yield > 0) else 0.0

        results.append({
            'crop':                      display_crop,
            'region':                    region_key.title(),
            'year':                      year,
            'predicted_yield_kg_per_ha': round(curr_yield, 1),
            'area_ha':                   round(curr_area or 0, 0),
            'production_tonnes':         round(curr_prod or 0, 0),
            'trend_pct':                 trend_pct,
            'is_positive':               trend_pct >= 0,
            'is_model_prediction':       is_model,
        })

    return JSONResponse(content={
        'year':           year,
        'data_years':     fao_years,
        'forecast_years': forecast_years,
        'results':        results,
    })


# ── Helpers ────────────────────────────────────────────────────────────────────

def _serialise(obj):
    """Recursively convert datetimes/dates to ISO strings for JSON serialisation."""
    import datetime as _dt
    if isinstance(obj, dict):
        return {k: _serialise(v) for k, v in obj.items()}
    if isinstance(obj, (_dt.datetime, _dt.date)):
        return obj.isoformat()
    return obj


if __name__ == '__main__':
    import uvicorn
    _ = get_disease_model_assets()
    uvicorn.run('backend.fastapi.app:app', host='0.0.0.0', port=8000, reload=False)
