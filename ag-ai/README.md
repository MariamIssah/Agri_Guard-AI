# Agri-Guard AI: A Machine Learning System for Crop Yield Prediction and Plant Disease Diagnosis for Ghanaian Smallholder Farmers

**GitHub Repository:** https://github.com/MariamIssah/Agri_Guard-AI
**Live API:** https://agriguard-ai-production.up.railway.app
**API Docs:** https://agriguard-ai-production.up.railway.app/docs
**Flutter App README:** [agriguard_ai/README.md](agriguard_ai/README.md)

> **For moderators and reviewers:** You do not need to set up a local environment to test this project. The API is live at the URL above and the Flutter APK is pre-built in the root of this repository. See [Section 11](#11-installation-and-running-the-project) for full local setup, or install the APK directly from [agriguard_ai/README.md](agriguard_ai/README.md).

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Problems AgriGuard AI Solves](#2-problems-agriguard-ai-solves)
3. [System Architecture](#3-system-architecture)
4. [Folder Structure](#4-folder-structure)
5. [Data Sources](#5-data-sources)
6. [Feature Engineering](#6-feature-engineering)
7. [Model Training and Results](#7-model-training-and-results)
8. [Disease Diagnosis System](#8-disease-diagnosis-system)
9. [Continuous Learning Pipeline](#9-continuous-learning-pipeline)
10. [API Documentation](#10-api-documentation)
11. [Installation and Running the Project](#11-installation-and-running-the-project)
12. [Flutter Mobile App Setup](#12-flutter-mobile-app-setup)
13. [Deployment](#13-deployment)
14. [Defense Panel Feedback and Responses](#14-defense-panel-feedback-and-responses)

---

## 1. Project Overview

AgriGuard AI is a full-stack agricultural intelligence platform built for Ghanaian smallholder farmers. It combines machine learning-based crop yield prediction, plant disease diagnosis (CNN image classification locally, rule-based text advisory on cloud), a farm diary system, and a buyer marketplace — all accessible through a Flutter Android application connected to a FastAPI backend deployed on Railway.

The platform serves three user roles:
- **Farmers** — receive personalised yield forecasts, disease diagnosis, treatment recommendations, and farm diary tracking
- **Buyers** — access regional supply forecasts and connect with farmers listing available harvest
- **Admins** — monitor platform statistics, manage users, and trigger model retraining

---

## 2. Problems AgriGuard AI Solves

AgriGuard AI addresses four interconnected challenges facing Ghanaian smallholder farmers:

### Challenge 1 — Crop Disease Goes Undetected Until It Is Too Late
Farmers cannot reliably identify what disease is affecting their crops. By the time an extension officer is consulted, significant damage has already occurred. The disease diagnosis system gives farmers an immediate first diagnosis from either a photograph (ResNet18 CNN — 38 disease classes) or a symptom description (rule-based advisory engine — 80 disease conditions across 13 Ghanaian crops), with specific treatment and prevention recommendations.

### Challenge 2 — Farmers Plan Without Data
No existing tool available to Ghanaian smallholders combines their specific crop variety, district, fertiliser usage, pest history, irrigation, and real-time weather conditions into a farm-level yield forecast. Extension officer advice is generalised and not tailored to an individual farm. Ghana's average maize yield of 1.7 MT/ha against a proven potential of 4.0 MT/ha (MoFA Ghana, FAOSTAT 2023) reflects this planning gap. AgriGuard AI provides each farmer with a specific, evidence-based yield estimate for their own farm — not a national average.

### Challenge 3 — Farmers and Buyers Cannot Find Each Other
Farmers harvest without knowing where to sell. Buyers cannot forecast regional supply before harvest time. The buyer marketplace connects both sides — farmers list their available harvest and buyers view predicted supply by crop and region before the season ends, reducing post-harvest losses from unsold produce.

### Challenge 4 — No Digital Record-Keeping for Smallholders
Farmers have no structured way to log planting activities, fertiliser applications, pest events, or growing conditions. The farm diary provides this, and every diary entry feeds directly into improving the yield prediction model through continuous learning — creating a system where using the app makes predictions more accurate over time.

---

## 3. System Architecture

```
┌──────────────────────────────────────────────────────────┐
│               Flutter Android Application                 │
│         24 screens · 3 roles (Farmer/Buyer/Admin)        │
└───────────────────────┬──────────────────────────────────┘
                        │ HTTPS REST API
                        ▼
┌──────────────────────────────────────────────────────────┐
│              FastAPI Backend (Railway)                    │
│         30+ endpoints · Python 3.11                      │
│                                                           │
│  ┌─────────────────┐   ┌──────────────────────────────┐  │
│  │ Prediction      │   │ Advisory System              │  │
│  │ System (GBM)    │   │ ResNet18 CNN + Rule Engine   │  │
│  │ R²=0.9266       │   │ 38 diseases · 13 crops       │  │
│  └─────────────────┘   └──────────────────────────────┘  │
└───────────────────────┬──────────────────────────────────┘
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
┌─────────────────┐       ┌─────────────────────┐
│ Supabase        │       │ OpenWeather API      │
│ PostgreSQL DB   │       │ Real-time weather    │
│ Row-level RLS   │       └─────────────────────┘
└─────────────────┘
```

---

## 4. Folder Structure

```
ag-ai/
├── Prediction System/
│   ├── compare_models.py          ← Train both models, compare, save winner
│   ├── predictor.py               ← Unified inference class (AgriGuardPredictor)
│   ├── data_prep.py               ← Load, merge, and engineer all 17 features
│   ├── train_model_legacy.py      ← Legacy training script (reference only)
│   └── models/
│       ├── best_model.joblib      ← Production model (GBM, R²=0.9266)
│       ├── advanced_model.joblib  ← Gradient Boosting model
│       ├── baseline_model.joblib  ← Random Forest baseline
│       ├── best_model_backup.joblib ← Previous production model backup
│       └── comparison_report.json ← Last retrain evaluation report
│
├── Advisory system/
│   ├── advisory_engine.py         ← Rule-based keyword-voting symptom engine
│   ├── disease_model.py           ← ResNet18 image classifier (ONNX + PyTorch)
│   ├── finetune_disease_model.py  ← Full fine-tuning script (Phase 2)
│   ├── retrain_disease_model.py   ← Retraining script with class balancing
│   └── models/disease/
│       ├── disease_model.pth      ← ResNet18 weights
│       ├── model_config.json      ← Model metadata and accuracy
│       ├── class_names.json       ← 38 disease class labels
│       └── label_encoder.pkl      ← Label encoder for inference
│
├── backend/fastapi/
│   ├── app.py                     ← FastAPI application (30+ endpoints)
│   └── db.py                      ← Supabase/PostgreSQL schema and queries
│
├── agriguard_ai/                  ← Flutter mobile app source code
│
├── dataset/
│   └── data/historical/
│       ├── agri_guard_merged_training_data.csv   ← Final merged training set (902 rows)
│       ├── FAOSTAT_data_en_6-16-2026.csv
│       ├── API_AG.CON.FERT.ZS_DS2_*.csv          ← World Bank fertiliser data
│       └── API_AG.LND.AGRI.K2_DS2_*.csv          ← World Bank land area data
│
├── requirements.txt               ← Python dependencies (pinned versions)
├── railway.toml                   ← Railway deployment configuration
└── Procfile                       ← Uvicorn start command
```

---

## 5. Data Sources

The yield prediction model is trained on a merged dataset from three independent real-world sources:

### Source 1 — MoFA Ghana (Ministry of Food and Agriculture)
- **Records:** 902 rows
- **Coverage:** 48 crops, 10 regions, 147 districts, 2012–2024
- **Fields:** Crop, Region, District, Year, Area_Planted_ha, Yield_kg_per_ha, Production_tonnes

### Source 2 — FAOSTAT (UN Food and Agriculture Organization)
- Ghana national-level crop production statistics, 2012–2024
- Used as cross-reference and regional forecast baseline

### Source 3 — World Bank Development Indicators
- `API_AG.CON.FERT.ZS` — Fertiliser consumption (kg per ha of arable land), joined on Year
- `API_AG.LND.AGRI.K2` — Agricultural land area (km²), joined on Year

### Source 4 — Farmer Submissions and Farm Diary (Live, via Supabase)
- Real ground-truth harvest yields submitted by farmers through the app
- Daily farm diary entries: temperature, rainfall, fertiliser applications, pest and disease events, irrigation days
- These feed the continuous learning pipeline — every 5 new submissions trigger an automatic model retrain

### Disease Diagnosis Dataset — PlantVillage
- 38 disease classes across 13 crop types
- Approximately 9,500 images (capped at 250 per class during fine-tuning, 1,500 per class during full retrain)
- Split: 80% train / 20% validation

---

## 6. Feature Engineering

The prediction model uses **17 features** — 7 core features present in all training rows, plus 10 diary/in-season features that are populated from farmer diary entries and real-time weather data.

### Core Features (always available)

| Feature | Type | Source | Description |
|---|---|---|---|
| `Crop_encoded` | Integer | Farmer input | 48 unique crop types, label-encoded |
| `Region_encoded` | Integer | Farmer input | 10 Ghana regions, label-encoded |
| `District_encoded` | Integer | Farmer input | 147 districts, label-encoded |
| `Area_Planted_ha` | Float | Farmer input | Farm area in hectares |
| `Year` | Integer | Record date | Harvest year — captures national yield trend |
| `national_fertilizer_kg_ha` | Float | World Bank | National fertiliser intensity that year |
| `national_agri_land_km2` | Float | World Bank | Total Ghana agricultural land that year |

### Diary / In-Season Features (from farm diary + OpenWeather API)

| Feature | Type | Source | Description |
|---|---|---|---|
| `avg_temp_max_c` | Float | OpenWeather / Diary | Average daily maximum temperature |
| `avg_temp_min_c` | Float | OpenWeather / Diary | Average daily minimum temperature |
| `total_rainfall_mm` | Float | OpenWeather / Diary | Total season rainfall in millimetres |
| `gdd` | Float | Calculated | Growing degree days (heat accumulation) |
| `fertilizer_kg_ha` | Float | Farm diary | Actual farm-level fertiliser applied |
| `fertilizer_applications` | Float | Farm diary | Number of fertiliser applications |
| `pest_events` | Float | Farm diary | Number of logged pest incidents |
| `disease_events` | Float | Farm diary | Number of logged disease incidents |
| `irrigation_days` | Float | Farm diary | Number of days irrigation was applied |
| `quality_score` | Float | Farmer input | Self-assessed crop quality (1–10) |

**Target variable:** `Yield_kg_per_ha` (continuous numeric — regression task, not classification)

### Why These Features Cannot Be Replaced by a Formula

A formula assumes fixed relationships between inputs and output. In Ghanaian agriculture, these relationships are non-linear and interactive: the effect of fertiliser on yield depends on rainfall; the effect of rainfall depends on the crop type; the effect of crop type depends on the region. A farmer applying 50 kg/ha of fertiliser during drought in Upper East will see a fundamentally different yield response from a farmer applying the same amount during a high-rainfall season in Ashanti. Gradient Boosting captures these conditional, interacting relationships across all 17 dimensions simultaneously — which is why it achieves R²=0.9266 on data it has never seen.

---

## 7. Model Training and Results

Two models are trained on the same data split and compared. The winner is saved as `best_model.joblib` and loaded by the production API.

### Baseline — Random Forest Regressor

```python
RandomForestRegressor(
    n_estimators=200,
    max_depth=20,
    min_samples_split=5,
    min_samples_leaf=2,
    max_features='sqrt',
    n_jobs=-1,
    random_state=42
)
```

### Production — Gradient Boosting Regressor

```python
GradientBoostingRegressor(
    n_estimators=1000,
    max_depth=6,
    learning_rate=0.05,
    subsample=0.85,
    min_samples_leaf=3,
    max_features='sqrt',
    loss='squared_error',
    random_state=42
)
```

### Train/Test Split

- 902 total rows → **80% train (721 rows), 20% test (181 rows)**
- `random_state=42` ensures the same split every run for reproducibility
- No cross-validation — a single held-out test set was used for all evaluation

### Results

| Metric | Random Forest (Baseline) | Gradient Boosting (Production) |
|---|---|---|
| R² Test | 0.636 | **0.9266** |
| MAE (kg/ha) | 3,334 | **1,259** |
| RMSE (kg/ha) | ~5,200 | **~2,491** |
| Training time | ~1s | ~8s |
| Training samples | 721 | 721 |
| Test samples | 181 | 181 |

**R²=0.9266** means the Gradient Boosting model explains 92.7% of yield variation across farms on held-out data it was never trained on. **MAE=1,259 kg/ha** means the average prediction error is 1,259 kg per hectare.

### Why Gradient Boosting Outperforms Random Forest

Random Forest trains 200 independent trees in parallel and averages their predictions. No tree learns from the errors of the others — the ensemble improves by averaging out noise. Gradient Boosting trains 1,000 trees sequentially: each new tree is explicitly fitted to the prediction errors (residuals) of the trees before it. Later trees focus specifically on the hardest cases — unusual crop-region-climate combinations that the earlier trees got wrong. This sequential error correction is why Gradient Boosting reduced the MAE from 3,334 kg/ha to 1,259 kg/ha — a 62% improvement.

### Quality Gate

When a retrain is triggered, the new model only replaces the production model if its R² is equal to or better than the current production model:

```python
updated = new_r2 >= prev_r2 or is_first_save
```

If the retrain produces a worse model, `best_model.joblib` is not changed. The previous production model is always backed up to `best_model_backup.joblib` before any overwrite.

### Run Training Locally

```bash
cd ag-ai
python "Prediction System/compare_models.py"
```

Outputs:
- `Prediction System/models/baseline_model.joblib`
- `Prediction System/models/advanced_model.joblib`
- `Prediction System/models/best_model.joblib` (GBM if it wins)
- `Prediction System/models/comparison_report.json`

---

## 8. Disease Diagnosis System

### Model Progression

The disease model was developed in three stages:

| Stage | Model | Parameters | Validation Accuracy | Notes |
|---|---|---|---|---|
| Baseline | Custom CNN | ~500K | — | Trained from scratch |
| Intermediate | MobileNetV3-Small | ~2.5M | — | Pretrained ImageNet |
| Production | **ResNet18** | ~11M | See model_config.json | Two-phase fine-tuning |

### ResNet18 — Production Model

ResNet-18 is a convolutional neural network with 18 layers pre-trained on ImageNet (1M+ images, 1,000 classes). This pre-training means the model already knows how to detect edges, textures, colours, and shapes in natural images. When applied to plant disease classification, these learned features transfer directly to leaf texture and colour patterns that distinguish between diseases. The residual connections in ResNet-18 allow gradients to flow through deep layers without vanishing during training, enabling effective fine-tuning.

**Two-phase training:**
- Phase 1: Backbone frozen, only the classification head trained (3 epochs, lr=9e-4)
- Phase 2: Full network unfrozen, discriminative learning rates applied (15 epochs, lr=3e-5)

Discriminative learning rates apply lower learning rates to earlier layers (which learned general features that should not change much) and higher rates to later layers (which learn task-specific patterns):
- layer1: lr × 0.1
- layer2: lr × 0.2
- layer3: lr × 0.5
- layer4: lr × 0.8
- classifier head: lr (full rate)

**Deployment:** ONNX Runtime — PyTorch is not required on the production server. Inference takes 1.2–1.5 seconds on CPU.

### Handling Outdoor Field Photographs

Field photographs taken by farmers are affected by sunlight glare, shadows, wet leaves, and non-uniform backgrounds. The system handles this with:

1. **Glare correction:** percentile contrast stretching (2nd to 98th percentile per colour channel) applied to every image before it reaches the model. This recovers detail from overexposed areas without washing out colours.
2. **Confidence gate:** if the CNN confidence score is below 60%, the system does not return a low-confidence image diagnosis. Instead, it automatically routes to the text-based symptom advisory engine.

### Text-Based Advisory Engine (Fallback)

A rule-based expert system using keyword voting. The farmer describes symptoms in text. Matched keywords add weighted votes to candidate diseases. The disease with the highest total score is returned with treatment and prevention recommendations. Covers 13 crops and 80 disease conditions. Works fully on the cloud API without PyTorch.

---

## 9. Continuous Learning Pipeline

The yield prediction model improves automatically as farmers use the platform.

### Auto-Trigger (Every 5 Submissions)

```
Farmer submits harvest → total count checked → if total % 5 == 0:
    background thread starts → compare_models.run_comparison(use_db=True)
    → new model evaluated → quality gate applied → best_model.joblib updated if improved
    → model artifact persisted to Supabase (survives Railway restart)
```

The farmer receives their response immediately. The retrain runs in a background thread and does not block the API.

### What the Retrain Uses

1. All 902 original MoFA Ghana historical records
2. All farmer harvest submissions stored in Supabase
3. All farm diary entries aggregated per submission (the 10 diary features)

As farmer participation grows, the model becomes increasingly grounded in real observed yields from specific Ghanaian districts — not extrapolated from regional or national averages.

### Admin Manual Trigger

```
POST /api/admin/retrain?admin_key=YOUR_KEY
```

Forces a full retrain outside the 5-submission cycle. Returns the new vs previous R², MAE, and whether the production model was updated.

### Model Persistence Across Railway Restarts

Railway's servers are ephemeral — files are lost on restart. Every promoted model is also saved to Supabase as binary bytes. On startup, the server downloads the Supabase version if the on-disk version is missing or has a lower R².

---

## 10. API Documentation

**Base URL:** `https://agriguard-ai-production.up.railway.app`
**Interactive Docs:** `/docs` (Swagger UI — full request/response schemas)

### Authentication

| Endpoint | Method | Description |
|---|---|---|
| `/api/auth/register` | POST | Register new farmer or buyer account |
| `/api/auth/login` | POST | Login and receive user token |
| `/api/auth/google` | POST | Google OAuth login/registration |
| `/api/auth/reset-password` | POST | Password reset |

### Prediction

| Endpoint | Method | Description |
|---|---|---|
| `/api/get-prediction` | POST | Farm-level yield prediction with confidence interval |
| `/api/buyer-predict` | POST | Regional aggregate supply forecast for buyers |
| `/api/predict/post-harvest` | POST | Submit actual harvest (feeds continuous learning) |
| `/api/regional-forecast` | GET | Regional yield forecast overview |

### Disease Advisory

| Endpoint | Method | Description |
|---|---|---|
| `/api/diagnose-disease` | POST | Text-based symptom diagnosis |
| `/api/diagnose-disease-image` | POST | Image-based CNN diagnosis (local API only) |

### Farm Diary

| Endpoint | Method | Description |
|---|---|---|
| `/api/diary` | POST | Submit daily farm diary entry |
| `/api/diary/my-entries` | GET | View farmer's own diary entries |
| `/api/diary/in-season-forecast` | GET | In-season yield forecast using diary data |
| `/api/harvest/actuals` | GET | View all submitted harvest actuals |
| `/api/harvest/my-submissions` | GET | View farmer's own submission history |

### Admin

| Endpoint | Method | Description |
|---|---|---|
| `/api/admin/retrain` | POST | Trigger full model retrain |
| `/api/admin/retrain-history` | GET | View comparison report from last retrain |
| `/api/admin/model-comparison` | GET | RF vs GBM metrics side by side |
| `/api/admin/stats` | GET | Platform usage statistics |
| `/api/admin/users` | GET | All registered users |

Admin endpoints require `admin_key` query parameter.

---

## 11. Installation and Running the Project

### Prerequisites

- Python 3.10 or 3.11
- Git
- A Supabase account with a PostgreSQL database (or use the live Railway API)

### Step 1 — Clone the Repository

```bash
git clone https://github.com/MariamIssah/Agri_Guard-AI.git
cd Agri_Guard-AI/ag-ai
```

### Step 2 — Create a Python Virtual Environment

```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# Mac / Linux
python -m venv .venv
source .venv/bin/activate
```

### Step 3 — Install Python Dependencies

```bash
pip install -r requirements.txt
```

Key packages installed:

| Package | Version | Purpose |
|---|---|---|
| fastapi | 0.138.0 | API framework |
| uvicorn | 0.49.0 | ASGI server |
| scikit-learn | 1.9.0 | ML models (RF, GBM) |
| pandas | 2.3.2 | Data loading and merging |
| numpy | 2.3.0 | Numerical operations |
| joblib | 1.5.1 | Model serialisation |
| psycopg2-binary | 2.9.10 | PostgreSQL connection |
| pydantic | 2.13.4 | Request/response validation |
| python-dotenv | 1.1.1 | Environment variable loading |
| torch | (optional) | Disease CNN — local only |
| torchvision | (optional) | Image transforms |
| onnxruntime | 1.27.0 | Fast CNN inference without PyTorch |

> **Note:** PyTorch (`torch`, `torchvision`) is required only if you want to run image-based disease diagnosis locally. The cloud API uses only ONNX Runtime. If you do not need image diagnosis, PyTorch installation can be skipped.

### Step 4 — Configure Environment Variables

Create a `.env` file in the `ag-ai/` directory:

```
DATABASE_URL=your_supabase_postgresql_connection_string
ADMIN_EMAIL=your_admin_email@example.com
ADMIN_PASSWORD=your_admin_password
OPENWEATHER_API_KEY=your_openweather_api_key
```

> If you do not have a Supabase database, the API will still start but will not persist farmer data. All prediction and advisory features work without a database.

### Step 5 — Train the Yield Prediction Models

```bash
python "Prediction System/compare_models.py"
```

This will:
- Load the MoFA Ghana dataset from `dataset/data/historical/`
- Train both the Random Forest baseline and Gradient Boosting production model
- Print a full comparison report with R², MAE, RMSE, and feature importances
- Save `models/best_model.joblib`, `models/baseline_model.joblib`, `models/advanced_model.joblib`

Expected output (last section):

```
  Winner:    Advanced (Gradient Boosting)
  R² gain:   +29 percentage points on held-out test set
  MAE gain:  +2,075 kg/ha reduction in average error
```

### Step 6 — Start the API Server

```bash
python -m uvicorn backend.fastapi.app:app --host 0.0.0.0 --port 8002 --reload
```

The API is now available at:
- `http://localhost:8002` — API root
- `http://localhost:8002/docs` — Swagger UI with all endpoints and request schemas

### Step 7 — Test the API

Open `http://localhost:8002/docs` in a browser and use the interactive Swagger UI to:
1. Register a test farmer account via `POST /api/auth/register`
2. Login via `POST /api/auth/login`
3. Request a yield prediction via `POST /api/get-prediction`
4. Test text-based disease diagnosis via `POST /api/diagnose-disease`

### Running Disease Diagnosis Locally (Image-Based)

Image diagnosis requires PyTorch and the trained model weights:

```bash
# Install PyTorch (CPU only — no GPU required)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# The disease model weights should be in:
# Advisory system/models/disease/disease_model.pth
# Advisory system/models/disease/class_names.json
# Advisory system/models/disease/model_config.json
```

If the model weights are not present, run the fine-tuning script with the PlantVillage dataset:

```bash
cd "Advisory system"
python finetune_disease_model.py
```

---

## 12. Flutter Mobile App Setup

See the full Flutter setup guide: [agriguard_ai/README.md](agriguard_ai/README.md)

**Quick install (no build required):**
1. Download `AgriGuard-AI.apk` from the root of this repository
2. Transfer to Android phone and install (enable "Unknown sources" in Settings → Security)
3. The app connects to the live Railway API automatically

**Connect Flutter app to your local API:**

```bash
# Allow phone to reach your PC's local API over USB
adb reverse tcp:8002 tcp:8002

# Run app pointing to local API
cd agriguard_ai
flutter pub get
flutter run --dart-define=AGRI_GUARD_BACKEND_URL=http://127.0.0.1:8002
```

---

## 13. Deployment

The API is deployed on Railway and auto-deploys on every push to the `main` branch.

**Start command (`Procfile`):**
```
web: uvicorn backend.fastapi.app:app --host 0.0.0.0 --port $PORT
```

**Required environment variables on Railway:**
```
DATABASE_URL
ADMIN_EMAIL
ADMIN_PASSWORD
OPENWEATHER_API_KEY
```

**What is NOT deployed on Railway:**
- PyTorch disease image model — the ResNet18 CNN requires PyTorch (~2GB), which exceeds Railway's free-tier build size. Image diagnosis is available only on the local API. The cloud API uses the text-based advisory engine as the disease diagnosis fallback.

---

## 14. Defense Panel Feedback and Responses

*Capstone Defense Date: 29 July 2026*
*Panel: Mr. Hubert (Supervisor), Mr. Simeon*

The following section documents the questions and challenges raised during my capstone defense presentation, my responses, and how I have incorporated the feedback into this final report and the project codebase.

---

### Question 1 — What Is the Challenge AgriGuard AI Is Solving?

**Question raised by Mr. Hubert:**
Mr. Hubert asked what exactly the challenge is that AgriGuard AI is solving and how the system addresses it.

**My response:**
AgriGuard AI does not claim to solve yield prediction as a standalone research problem. The system addresses four practical, interconnected challenges facing Ghanaian smallholder farmers:

1. Farmers cannot identify crop diseases early enough. By the time an extension officer is consulted, yield loss has already occurred. The disease diagnosis system covers 38 disease conditions across 13 Ghanaian crops and gives an immediate first diagnosis from either a photograph or a symptom description.

2. Farmers make planting and selling decisions without personalised data. Ghana's average maize yield is 1.7 MT/ha against a proven potential of 4.0 MT/ha. That gap is partly caused by input decisions made without evidence. The yield prediction system takes 17 farm-specific inputs and returns a farm-level forecast with a confidence interval — giving each farmer something concrete to plan around, not a national average.

3. Farmers and buyers cannot find each other before harvest time. The buyer marketplace and regional forecast connect supply and demand so farmers do not harvest into an unknown market.

4. Smallholder farmers have no digital farm record system. The farm diary solves this, and every record logged feeds back into improving yield predictions through continuous learning.

**How this was incorporated:**
The problem statement chapter in the report has been rewritten to clearly present all four challenges. Yield prediction is positioned as one component of a broader farm intelligence platform, not as the sole problem being solved.

---

### Question 2 — What Is ResNet-18 and How Was It Used?

**Question raised by Mr. Simeon:**
Mr. Simeon asked what ResNet-18 is and how it was applied in the disease diagnosis system.

**My answer:**
ResNet-18 is a convolutional neural network with 18 layers and approximately 11 million parameters, originally trained on ImageNet — over one million images across one thousand categories. Through that pre-training, the model already knows how to detect edges, textures, colours, and shapes in natural images. When applied to plant disease classification, those learned features transfer directly to the visual patterns that distinguish between diseases — leaf texture, discolouration, spot shape, and lesion distribution.

I used a two-phase training approach. In the first phase, the backbone was frozen and only the final classification head was trained. This was fast and established the correct mapping from ResNet features to the 38 disease classes. In the second phase, the full network was fine-tuned with discriminative learning rates — earlier layers updated very slowly because they already learned useful general features, while later layers updated more aggressively to adapt to disease-specific patterns.

The disease model was developed in three stages: a custom CNN trained from scratch as the baseline, then MobileNetV3-Small as an intermediate improvement, and finally ResNet-18 as the production model. ResNet-18 was chosen because its residual connections prevent the gradient from vanishing in deep layers, allowing effective fine-tuning.

**How this was incorporated:**
The advisory system chapter now documents all three model stages with the rationale for each upgrade, rather than presenting ResNet-18 in isolation.

---

### Question 3 — Why Gradient Boosting and What Is the Methodology?

**Question raised by Mr. Simeon:**
Mr. Simeon asked why I used Gradient Boosting and what the methodology behind it is compared to Random Forest.

**My answer:**
Gradient Boosting works sequentially. The first tree makes a prediction. The second tree is specifically trained to correct the error of the first. The third tree targets what the first two trees combined still got wrong. This continues for 1,000 trees — each one focusing on the remaining mistakes of the ensemble before it.

The analogy I used: if you ask me a question and tell me what is wrong with my first answer, I now focus entirely on correcting that specific mistake. That is exactly what each tree in Gradient Boosting does. Random Forest gives the same question independently to 200 people and takes a majority vote — it reduces noise by averaging, but no individual learner corrects the others.

For crop yield prediction, where unusual crop-region-climate combinations are the hardest to get right, sequential error correction outperforms averaging. This is why Gradient Boosting reduced the MAE from 3,334 kg/ha (Random Forest) to 1,259 kg/ha — a 62% improvement.

**How this was incorporated:**
The model comparison section of the report includes this explanation alongside the performance metrics table.

---

### Question 4 — Web Application versus Mobile Application

**Challenge raised by Mr. Hubert:**
Mr. Hubert argued that a web application would have been more accessible — every device has a browser — and easier to develop than Flutter, which requires learning a new framework. He suggested that given the project timeline, a web application would have been the better choice.

**The misunderstanding during my response:**
During my answer, I was explaining a specific challenge with disease diagnosis — that field photographs taken outdoors in direct sunlight may produce lower confidence scores from the CNN because of glare and background variation, and that in those cases the text-based symptom advisory is the alternative. Mr. Hubert interpreted this as me saying the mobile application itself does not perform well. That was not what I intended. I was describing an image quality challenge specific to outdoor photography, not a failure of the mobile platform.

The system already handles this in two ways: glare correction (percentile contrast stretching applied to every photo before inference) and a confidence gate (if the model is less than 60% confident, it automatically routes to the text advisory instead of returning a low-confidence result).

**On the web versus mobile decision:**
I acknowledge Mr. Hubert's point. Learning Flutter while building the ML backend and full-stack API simultaneously was the most time-intensive part of this project, and a web application would have been faster to develop. The decision to use Flutter was based on farmer interviews showing that rural users are more comfortable with installed applications than browser links, and that sharing an APK over WhatsApp is more reliable in low-connectivity areas than sharing a URL. I accept that a Progressive Web App would have been a reasonable alternative within the timeline.

**How this was incorporated:**
The system design chapter now includes a platform trade-off discussion presenting both sides. The disease diagnosis section documents the glare correction and confidence fallback to make clear that outdoor image quality is a handled limitation, not an unresolved one.

---

### Question 5 — Parameters and Machine Learning: Could a Spreadsheet Formula Do the Same Thing?

**Challenge raised by Mr. Hubert:**
Mr. Hubert challenged the necessity of machine learning. Based on the parameters I described during the presentation, he said the prediction could be done with a simple formula, and that important factors like soil nitrogen were absent. He recommended either adding parameters that truly require ML or simplifying to a formula.

**What I was trying to explain (and was interrupted before finishing):**
I was cut off multiple times before I could complete my explanation. The model uses 17 features — not the 7 I managed to name during the presentation. The 10 additional features come from the farm diary and real-time weather data: average maximum and minimum temperature, total seasonal rainfall, growing degree days, farm-level fertiliser amount and number of applications, pest events, disease events, irrigation days, and a quality score. I was also trying to explain the continuous learning pipeline — that the model retrains automatically on real farmer harvest data every 5 submissions — which a formula cannot do.

A formula cannot replicate what the model does because the relationships between these 17 inputs are non-linear and interactive. The effect of fertiliser on yield is not fixed — it depends on the rainfall that season. The effect of rainfall depends on the crop type. The effect of crop type depends on the region. Gradient Boosting captures all of these conditional interactions simultaneously across 48 crops, 10 regions, and 147 districts. This is why the model achieves R²=0.9266 on held-out data — explaining 92.7% of yield differences between farms. No formula can produce this result across such diverse conditions.

**Acknowledgement of the valid point:**
Mr. Hubert's observation that soil nitrogen and soil pH are absent is correct. These are real drivers of yield that are missing because collecting soil data per farmer without laboratory testing is not currently feasible at scale. This limitation is now documented in the limitations chapter. Satellite-derived soil data integration (SoilGrids / ISRIC) is listed as a future work priority.

**How this was incorporated:**
The methodology chapter now includes the complete 17-feature table with sources. A paragraph explains why non-linear feature interactions require machine learning rather than a formula. Continuous learning is documented as a feature that explicitly cannot be replicated with a formula. The absence of soil data is acknowledged in the limitations section.

---

### Closing Remarks

Mr. Simeon gave a commendation at the close of the session and wished the student well in future endeavours.

Mr. Aaron thanked the student for the presentation and also offered best wishes. Mr. Aaron did not raise technical questions during the session.
