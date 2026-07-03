# AgriGuard AI — Core ML Pipeline and API Documentation

**Live API:** https://agriguard-ai-production.up.railway.app  
**API Docs:** https://agriguard-ai-production.up.railway.app/docs  
**Full Project README:** [Agri_Guard-AI/README.md](../README.md)

---

## Table of Contents

1. [Folder Structure](#1-folder-structure)
2. [Data Sources and Merging](#2-data-sources-and-merging)
3. [Feature Engineering](#3-feature-engineering)
4. [Model Training and Evaluation](#4-model-training-and-evaluation)
5. [Continuous Learning Pipeline](#5-continuous-learning-pipeline)
6. [API Documentation](#6-api-documentation)
7. [Deployment](#7-deployment)
8. [Installation](#8-installation)

---

## 1. Folder Structure

```
ag-ai/
├── Prediction System/
│   ├── compare_models.py          ← Train both models, compare, save winner
│   ├── predictor.py               ← Unified inference class (AgriGuardPredictor)
│   ├── data_prep.py               ← Load, merge, and engineer features
│   └── models/
│       ├── best_model.joblib      ← Gradient Boosting winner — used in production
│       ├── advanced_model.joblib  ← GBM (R² = 0.90)
│       └── baseline_model.joblib  ← Random Forest (R² = 0.54)
│
├── Advisory system/
│   ├── advisory_engine.py         ← Text-based symptom → disease diagnosis
│   └── disease_model.py           ← CNN image classifier (PyTorch, local use only)
│
├── backend/fastapi/
│   ├── app.py                     ← FastAPI application — 13 endpoints
│   └── db.py                      ← PostgreSQL connection and schema
│
├── agriguard_ai/                  ← Flutter mobile app (see agriguard_ai/README.md)
│
├── dataset/
│   └── data/historical/
│       ├── agri_guard_merged_training_data.csv   ← Final merged training set
│       ├── FAOSTAT_data_en_6-16-2026.csv         ← UN FAO national statistics
│       ├── API_AG.CON.FERT.ZS_DS2_*.csv          ← World Bank fertilizer data
│       └── API_AG.LND.AGRI.K2_DS2_*.csv          ← World Bank land area data
│
├── requirements.txt               ← Python dependencies (pinned versions)
├── railway.toml                   ← Railway deployment config
└── Procfile                       ← Uvicorn start command for Railway
```

---

## 2. Data Sources and Merging

The model is trained on a merged dataset combining three independent sources:

### Source 1 — MoFA Ghana (Ministry of Food and Agriculture)
- **File:** `agri_guard_merged_training_data.csv`
- **Records:** 902 rows
- **Coverage:** 48 crops, 10 regions, 147 districts, 2012–2024
- **Fields:** Crop, Region, District, Year, Area_Planted_ha, Yield_kg_per_ha, Production_tonnes

### Source 2 — FAOSTAT (UN Food and Agriculture Organization)
- **File:** `FAOSTAT_data_en_6-16-2026.csv`
- **Coverage:** Ghana national-level crop statistics, 2012–2024
- **Use:** Cross-reference for national production totals; regional forecast baseline

### Source 3 — World Bank Development Indicators
- **File:** `API_AG.CON.FERT.ZS_DS2_*.csv` — Fertilizer consumption (kg per ha of arable land)
- **File:** `API_AG.LND.AGRI.K2_DS2_*.csv` — Agricultural land area (km²)
- **Use:** National-level macroeconomic context features joined on Year

### Merging Strategy

```python
# data_prep.py — simplified merge logic
mofa = pd.read_csv('agri_guard_merged_training_data.csv')
fert = pd.read_csv('API_AG.CON.FERT.ZS_DS2_*.csv')      # pivot to Year → value
land = pd.read_csv('API_AG.LND.AGRI.K2_DS2_*.csv')       # pivot to Year → value

# Left join MoFA records with World Bank indicators by year
df = mofa.merge(fert, on='Year', how='left')
df = df.merge(land, on='Year', how='left')
```

The join is deliberately a **left join** — every MoFA row is kept, and World Bank values fill in national context for that year. This preserves all 902 regional records while adding macroeconomic signal.

---

## 3. Feature Engineering

After merging, 7 features are selected for training:

| Feature | Type | Source | Importance |
|---|---|---|---|
| `Area_Planted_ha` | Numeric | Farmer input / MoFA | Scales directly with production |
| `Year` | Integer | Record date | Captures time trend (yield improving) |
| `Crop_encoded` | Integer | Label encoded | 48 unique crops |
| `Region_encoded` | Integer | Label encoded | 10 Ghana regions |
| `District_encoded` | Integer | Label encoded | 147 districts |
| `national_fertilizer_kg_ha` | Float | World Bank | National input intensity |
| `national_agri_land_km2` | Float | World Bank | National agricultural capacity |

### Label Encoding

Categorical text fields (crop name, region, district) are encoded with `sklearn.LabelEncoder`:

```python
le_crop = LabelEncoder()
df['Crop_encoded'] = le_crop.fit_transform(df['Crop'])

le_region = LabelEncoder()
df['Region_encoded'] = le_region.fit_transform(df['Region'])
```

The fitted encoders are saved alongside the models so inference-time text inputs are transformed identically to training.

**Target:** `Yield_kg_per_ha` (continuous, regression — **not** classification)

---

## 4. Model Training and Evaluation

Two models are trained and compared. The winner is saved as `best_model.joblib` and loaded by the API.

### Baseline — Random Forest

```python
from sklearn.ensemble import RandomForestRegressor
rf = RandomForestRegressor(n_estimators=100, max_depth=15,
                           min_samples_split=5, random_state=42, n_jobs=-1)
```

### Advanced — Gradient Boosting Machine (GBM)

```python
from sklearn.ensemble import GradientBoostingRegressor
gbm = GradientBoostingRegressor(n_estimators=200, learning_rate=0.1,
                                max_depth=5, min_samples_split=5,
                                subsample=0.8, random_state=42)
```

### Train/Test Split

- 902 total rows → 80% train (720 rows), 20% test (182 rows)
- `random_state=42` for reproducibility
- 5-fold cross-validation on training set for unbiased performance estimate

### Results

| Metric | Random Forest (Baseline) | Gradient Boosting (Production) |
|---|---|---|
| R² Train | 0.861 | 0.991 |
| **R² Test** | 0.539 | **0.897** |
| **MAE (kg/ha)** | 3,929 | **1,819** |
| RMSE (kg/ha) | 7,628 | 3,602 |
| 5-fold CV R² | 0.607 | **0.879** |
| Training time | 0.3s | 0.3s |

The GBM model wins decisively. R² = 0.897 means the model explains 89.7% of yield variance in data it has never seen. MAE = 1,819 kg/ha means predictions are off by roughly 1.8 tonnes per hectare on average.

### Why GBM Outperforms Random Forest

Random Forest builds trees in **parallel** and averages their votes — each tree sees a random subset of data. Gradient Boosting builds trees **sequentially** — each new tree explicitly corrects the errors of the previous ensemble. For crop yield prediction, which has complex interactions between crop type, region, year, and national indicators, sequential error correction captures non-linear dependencies that parallel averaging misses.

### Run Training

```bash
python "Prediction System/compare_models.py"
```

Outputs:
- `Prediction System/models/baseline_model.joblib`
- `Prediction System/models/advanced_model.joblib`
- `Prediction System/models/best_model.joblib` → copy of advanced (winner)

---

## 5. Continuous Learning Pipeline

This is what makes AgriGuard AI different from a standard ML deployment. **The model improves as farmers use the system.**

### How It Works

```
STAGE 1 — Farmer Submits Harvest
┌──────────────────────────────────────────────────────┐
│ POST /api/predict/post-harvest                        │
│ { crop, region, district, area_ha, actual_yield }    │
└────────────────────┬─────────────────────────────────┘
                     │ stored in PostgreSQL
                     ▼
STAGE 2 — Data Accumulates
┌──────────────────────────────────────────────────────┐
│  harvest_submissions table in Supabase               │
│  Growing dataset of REAL observed yields             │
└────────────────────┬─────────────────────────────────┘
                     │
                     │ admin triggers retrain
                     ▼
STAGE 3 — Model Retrain
┌──────────────────────────────────────────────────────┐
│ POST /api/admin/retrain                              │
│ 1. Load original MoFA dataset (902 rows)             │
│ 2. Load all farmer submissions from database         │
│ 3. Merge: new_data = concat([original, submissions]) │
│ 4. Re-run compare_models.py on combined dataset      │
│ 5. Save new best_model.joblib                        │
│ 6. Reload predictor in-memory (no restart needed)    │
└──────────────────────────────────────────────────────┘
```

### Why Continuous Learning Makes AgriGuard Unique

1. **Historical training data is national/regional.** It cannot reflect local soil conditions, local farming practices, or micro-climate effects that matter at the district and farm level.

2. **Farmer submissions are local ground truth.** A farmer in Navrongo, Upper East, submitting actual cassava yields for their specific fields provides data that no national survey captures. This is the highest-quality training signal possible.

3. **The model improves with real observations.** Each submitted yield is a labelled training example: we know exactly what crop, where, when, and what the actual output was.

4. **No developer intervention needed.** The admin retrain endpoint handles the entire pipeline automatically. A non-technical platform manager can update the model from the admin screen without writing a single line of code.

5. **Predictions converge on local reality over time.** As farmer participation grows, predictions for a specific district become grounded in real observed yields from that district — not extrapolated from regional averages.

6. **Creates a network effect.** More farmers participating → more training data → better predictions → more useful to buyers → more buyers using the platform → more incentive for farmers to participate. The system grows in value as it grows in users.

### Continuous Learning in Code

```python
# app.py — /api/admin/retrain endpoint
@app.post('/api/admin/retrain')
def retrain_model(admin_key: str):
    _check_admin(admin_key)

    # Pull farmer submissions from database
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT crop, region, district, year, area_planted_ha,
                   actual_yield_kg_per_ha as yield_kg_per_ha
            FROM harvest_submissions
            WHERE actual_yield_kg_per_ha IS NOT NULL
        """)
        submissions = cur.fetchall()

    if submissions:
        sub_df = pd.DataFrame(submissions, columns=[...])
        # Merge with original training data
        combined = pd.concat([original_df, sub_df], ignore_index=True)
        # Retrain both models on combined dataset
        train_and_save(combined)
        # Reload predictor in-memory — zero downtime
        predictor.reload()

    return {'status': 'retrained', 'new_rows': len(submissions)}
```

---

## 6. API Documentation

Base URL: `https://agriguard-ai-production.up.railway.app`  
Interactive docs: `/docs` (Swagger UI)

### Authentication

| Endpoint | Method | Body | Returns |
|---|---|---|---|
| `/api/auth/register` | POST | `{ email, password, role: "farmer"/"buyer" }` | `{ user_id, token }` |
| `/api/auth/login` | POST | `{ email, password }` | `{ user_id, token, role }` |

### Prediction

#### `POST /api/get-prediction`
Main yield prediction endpoint. Returns predicted yield, confidence interval, and disease advisory.

**Request body:**
```json
{
  "crop": "Maize",
  "region": "Northern",
  "district": "Tamale Metro",
  "area_planted_ha": 5.0,
  "year": 2025,
  "symptoms": "yellowing leaves, wilting"
}
```

**Response:**
```json
{
  "predicted_yield_kg_per_ha": 2810,
  "predicted_production_tonnes": 14.05,
  "confidence_interval": { "lower": 2100, "upper": 3520 },
  "disease_advisory": {
    "likely_disease": "Maize Streak Virus",
    "severity": "moderate",
    "treatment": "Remove infected plants, apply pyrethroid insecticide...",
    "yield_impact_factor": 0.85
  },
  "model_used": "GradientBoostingRegressor",
  "model_r2": 0.897
}
```

#### `GET /api/regional-forecast`
Supply forecast for all 32 crop-region combinations. Buyers use this for procurement planning.

**Query params:** `year` (optional, defaults to current year), `region` (optional filter)

**Response:** Array of `{ crop, region, total_area_ha, predicted_yield_kg_ha, total_production_tonnes, farmers_reporting }`

### Disease Advisory

#### `POST /api/diagnose-disease`
Text-based symptom diagnosis for 13 Ghana crops. Works without image upload.

**Request body:**
```json
{
  "crop": "Tomato",
  "symptoms": "brown spots on leaves, wilting, white powder on stem"
}
```

**Response:** `{ disease, confidence, treatment, prevention, yield_loss_estimate }`

### Farmer Data

| Endpoint | Method | Description |
|---|---|---|
| `POST /api/predict/post-harvest` | POST | Submit actual harvest (feeds continuous learning) |
| `POST /api/diary` | POST | Submit daily farm diary entry |
| `GET /api/harvest/actuals` | GET | View farmer submission history (authenticated) |

### Admin

| Endpoint | Method | Description |
|---|---|---|
| `POST /api/admin/retrain` | POST | Trigger model retrain with farmer submissions |
| `GET /api/admin/model-comparison` | GET | RF vs GBM metrics report |
| `GET /api/admin/stats` | GET | Platform usage statistics |
| `GET /api/admin/users` | GET | All registered users |

Admin endpoints require `admin_key` query parameter.  
Admin credentials: set via `ADMIN_EMAIL` and `ADMIN_PASSWORD` environment variables.

---

## 7. Deployment

### Railway (Production)

The API is deployed on Railway and auto-deploys on every push to the `main` branch of the GitHub repository.

**Configuration — `railway.toml`:**
```toml
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "uvicorn backend.fastapi.app:app --host 0.0.0.0 --port $PORT"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

**Environment variables required on Railway:**
```
DATABASE_URL=postgresql://...      ← Supabase connection string
ADMIN_EMAIL=admin@agriguard.ai
ADMIN_PASSWORD=agriguard2025
```

**Live URL:** `https://agriguard-ai-production.up.railway.app`

### What Is NOT on Railway

- **PyTorch disease image model** — ResNet18 CNN requires ~2GB PyTorch install, which exceeds Railway's free-tier build limits. The image diagnosis feature is available only when running the API locally with full Python dependencies.
- **Notebooks** — Excluded from git (`.gitignore: *.ipynb`) to keep repo size manageable.

---

## 8. Installation

### Local Development

```bash
# Clone
git clone https://github.com/MariamIssah/Agri_Guard-AI.git
cd Agri_Guard-AI/ag-ai

# Python environment
python -m venv .venv
.venv\Scripts\activate        # Windows
source .venv/bin/activate     # Mac/Linux
pip install -r requirements.txt

# Configure
# Create .env with your Supabase DATABASE_URL
echo DATABASE_URL=your_supabase_url > .env

# Train models
python "Prediction System/compare_models.py"

# Start API
python -m uvicorn backend.fastapi.app:app --host 0.0.0.0 --port 8002
```

API is now available at `http://localhost:8002/docs`

### Connect Mobile App to Local API

```bash
# For Android physical device via USB
adb reverse tcp:8002 tcp:8002
```

### Python Dependencies (Key Packages)

```
fastapi==0.138.0
uvicorn==0.49.0
scikit-learn==1.9.0
pandas==2.3.2
numpy==2.3.0
joblib==1.5.1
psycopg2-binary==2.9.10
pydantic==2.13.4
python-dotenv==1.1.1
```

Full list: [requirements.txt](requirements.txt)
