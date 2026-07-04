# AgriGuard AI — Crop Yield Prediction and Agricultural Supply Chain Intelligence

**Student:** Mariam Awini Issah  
**Programme:** BSc. Software Engineering, Machine Learning Specialisation  
**Institution:** African Leadership University (ALU)  
**Demo Video:** [Watch on YouTube](https://youtu.be/tvJdTJLd4-U)  
**Live API:** https://agriguard-ai-production.up.railway.app  
**APK Download:** [AgriGuard-AI.apk](AgriGuard-AI.apk)  
**GitHub Repo:** https://github.com/MariamIssah/Agri_Guard-AI

---

## The Problem

Agricultural supply chains in Ghana suffer from a critical visibility gap. Buyers — aggregators, processors, and exporters — have no reliable way to find out:
- Which crops are being grown and where
- How much will be harvested and when
- Which regions have surplus supply available for purchase

Meanwhile, smallholder farmers lose up to 40% of income to post-harvest losses because they cannot connect to buyers at the right time. There is no digital platform for farmers to record farm activities and no structured data system that turns those records into predictions buyers can act on.

---

## What AgriGuard AI Does

AgriGuard AI is an end-to-end intelligent agricultural platform with three tightly coupled layers:

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1 — DATA COLLECTION (Flutter Mobile App)             │
│  Farmers register farms, log crop activities, submit yields  │
│  Buyers view regional forecasts and source crop supply       │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  LAYER 2 — INTELLIGENCE (FastAPI + Machine Learning)         │
│  Gradient Boosting model predicts yield (R² = 0.90)          │
│  Regional supply forecasts across 32 crop-region pairs       │
│  Text-based crop disease advisory for 13 Ghana crops         │
│  Continuous learning — farmer data retrains the model live   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│  LAYER 3 — DATA STORAGE (Supabase PostgreSQL)                │
│  Users, farms, diary entries, harvest submissions            │
│  Growing dataset powers continuous model improvement         │
└─────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
Agri_Guard-AI/
├── AgriGuard-AI.apk           ← Installable Android app (download here)
├── README.md                  ← This file — full project overview
└── ag-ai/                     ← Core project codebase
    ├── README.md              ← ML pipeline, data, and API documentation
    ├── Prediction System/     ← Machine learning models and training
    ├── Advisory system/       ← Disease diagnosis engine
    ├── backend/fastapi/       ← REST API (FastAPI)
    ├── agriguard_ai/          ← Flutter mobile application
    │   └── README.md          ← App setup, screens, APK installation guide
    ├── dataset/               ← Training data (MoFA + FAOSTAT + World Bank)
    ├── requirements.txt       ← Python dependencies
    └── Procfile               ← Uvicorn start command
```

---

## Key Results

| Metric | Value |
|---|---|
| ML Model | Gradient Boosting Regressor |
| Test R² | **0.90** (vs 0.54 baseline Random Forest) |
| MAE | **1,819 kg/ha** |
| Training data | 902 rows, 48 crops, 10 regions, 2012–2024 |
| API endpoints | 13 endpoints (prediction, auth, admin, advisory) |
| Mobile screens | 12+ screens (farmer, buyer, admin, disease, diary) |
| Deployment | Live on Railway — always-on cloud API |
| Android APK | Release build, tested on Android 11 (TECNO KI5q) |

---

## What Makes AgriGuard Unique — Continuous Learning

Most agricultural ML systems are static: trained once, deployed, and never updated. AgriGuard AI is built differently. Every time a farmer submits their **actual harvest yield** through the mobile app, that record enters the database. The admin can trigger a model retrain with a single API call — the system automatically merges the new farmer submissions with the historical training data and produces an improved model.

This means the predictions improve over time as more Ghanaian farmers participate. It also means predictions increasingly reflect real local conditions (soil, rainfall, local practices) rather than purely national statistics. See [ag-ai/README.md](ag-ai/README.md) for the full pipeline explanation.

---

## How to Get Started

### Use the App (No Setup Needed)
1. Download [AgriGuard-AI.apk](AgriGuard-AI.apk)
2. Install on your Android phone (enable unknown sources in Settings)
3. The app connects to the live cloud API automatically

### Test the API
```
https://agriguard-ai-production.up.railway.app/docs
```
Interactive API documentation with all 13 endpoints.

### Read the Technical Documentation
- [ag-ai/README.md](ag-ai/README.md) — ML pipeline, data sources, model training, API, continuous learning
- [ag-ai/agriguard_ai/README.md](ag-ai/agriguard_ai/README.md) — Flutter app, screens, APK install guide

---

## Technology Stack

| Component | Technology | Why |
|---|---|---|
| Mobile App | Flutter (Dart) | Cross-platform Android, fast UI |
| API Server | FastAPI (Python) | Async, auto-docs, fast |
| ML Models | scikit-learn GBM + RF | Lightweight, no GPU required |
| Database | Supabase (PostgreSQL) | Managed, free tier, PostgREST |
| Cloud Hosting | Railway | Auto-deploy from GitHub, free tier |
| Disease Advisory | Voting-based NLP + ONNX CNN | Text and image diagnosis, deployed on cloud |

---

## Testing Results Summary

| Test Type | Result |
|---|---|
| GBM model on held-out test set (182 rows) | R² = 0.90, MAE = 1,819 kg/ha |
| Regional forecast (32 crop-region pairs) | ✅ Returns predictions for all combinations |
| API endpoint testing (all 13 endpoints) | ✅ All return correct responses |
| Mobile app on Android 11 (TECNO KI5q) | ✅ All screens load, predictions work |
| Cloud deployment on Railway | ✅ Live and serving |

---

## Analysis of Results

### What Worked Well

**Data fusion was the key unlock.** Merging three data sources — MoFA regional records, FAOSTAT national statistics, and World Bank macroeconomic indicators — gave the model features that explain yield variation beyond just crop type and region. The national fertilizer intensity and agricultural land area features contributed 18% of predictive power in the GBM model's feature importance analysis.

**Gradient Boosting outperformed the baseline by a large margin.** R² improved from 0.54 to 0.90 — a 35.85 percentage point gain. This confirms that crop yield in Ghana has complex non-linear dependencies (e.g., rice yield in the Volta region responds differently to fertilizer than maize in the Northern region) that sequential boosting captures but parallel averaging does not.

**The cloud deployment works end-to-end.** A buyer in Accra can open the app, select "Cassava, Ashanti, 68 ha" and receive a regional forecast in under 2 seconds, with no local server required.

### What Was Constrained

**Image disease diagnosis is fully deployed on Railway** using an ONNX-exported ResNet18 model (44.8MB), replacing the 2GB PyTorch install. Both text-based symptom diagnosis and image upload diagnosis work on the live cloud API.

**Pilot dataset is small (902 rows).** The model generalises reasonably but predictions for districts with few historical records (e.g., some Upper West districts) rely more on regional interpolation than local observation. As farmer submissions accumulate, these predictions will improve.

---

## Discussion

The most impactful milestone was the decision to build a continuous learning pipeline rather than a one-shot model. Agricultural ML systems typically require expert data scientists to retrain models periodically. AgriGuard's admin retrain endpoint (`/api/admin/retrain`) means any platform administrator — even a non-developer — can update the model as the farmer network grows. This creates a compounding improvement effect: more farmers → more training data → better predictions → more useful to buyers → more farmer adoption.

The regional forecast feature directly addresses the original supply chain problem. Rather than showing a buyer "what will my farm yield," it answers "what is the total expected production of maize in the Northern Region this season?" This is the data point that enables procurement planning.

---

## Recommendations

### For Farming Communities
- Submit actual harvest yields through the app after each season — this is the single most valuable action for improving prediction accuracy
- Use the crop diary daily during the growing season to build a record of practices that can be correlated with outcomes

### For Agricultural Stakeholders and Buyers
- Use the Regional Forecast screen 4–8 weeks before expected harvest for procurement planning
- The advisory engine covers 13 major Ghana crops — request additions through the admin panel

### For Policy and Future Work
- Integrate MoFA district extension officer records to reduce reliance on World Bank national averages
- Add offline mode for farmers in low-connectivity areas
- Expand image disease diagnosis by migrating ResNet18 to ONNX format for lightweight cloud inference
- Add weather API integration (OpenWeatherMap) for in-season yield adjustment forecasts
- Build a buyer-seller matching module on top of the regional forecast data

---

*AgriGuard AI v2.0 · Deployed July 2026 · African Leadership University Capstone*
