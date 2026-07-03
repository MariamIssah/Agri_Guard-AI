"""
Baseline Model Training — AgriGuard Prediction System
=====================================================

Model:     Random Forest Regressor (sklearn)
Rationale: Industry-standard ensemble baseline. Robust to outliers,
           requires no feature scaling, provides built-in feature
           importances, and generalises well with minimal tuning.

Features:  7 core features (crop, region, district, area, year +
           2 national World Bank indicators from Ghana).

Output:    Prediction System/models/baseline_model.joblib
"""

import sys
import os
import json
import datetime
import numpy as np
import pandas as pd
import joblib
from pathlib import Path
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import (
    mean_squared_error, mean_absolute_error,
    r2_score, mean_absolute_percentage_error,
)

# Allow imports from project root
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from data_prep import build_dataset, prepare_features, get_train_test_split

MODEL_DIR    = Path(__file__).resolve().parent / 'models'
MODEL_OUTPUT = MODEL_DIR / 'baseline_model.joblib'

# ── Hyperparameters ────────────────────────────────────────────────────────────
#
#  n_estimators  = 200
#    Why: More trees → more stable variance estimates. Beyond ~200 the
#    marginal gain diminishes sharply while training time grows linearly.
#    200 balances accuracy and speed for this dataset size (~800 rows).
#
#  max_depth  = 20
#    Why: Deep trees capture the complex non-linear relationships between
#    crop type, region, and yield (Crop alone explains ~66% variance).
#    Without a depth cap, individual trees would overfit; at depth=20 the
#    ensemble average smooths this out.
#
#  min_samples_split  = 5
#    Why: Prevents splitting on noisy splits in small sub-groups
#    (e.g. a rare district × rare crop combination). Keeps trees
#    generalizable.
#
#  min_samples_leaf  = 2
#    Why: Requires at least 2 samples per leaf — avoids singleton
#    leaves that memorise individual data points.
#
#  max_features  = 'sqrt'
#    Why: At each split, consider only sqrt(n_features) candidate features.
#    This decorrelates individual trees (they don't all pick the dominant
#    feature), which is what makes RF an ensemble rather than many copies
#    of the same tree.
#
#  random_state  = 42
#    Why: Fixed seed ensures reproducible results across runs.
#
#  n_jobs  = -1
#    Why: Parallelise across all CPU cores — trees are independent so this
#    gives a linear speedup with no effect on output.

RF_PARAMS = dict(
    n_estimators    = 200,
    max_depth       = 20,
    min_samples_split = 5,
    min_samples_leaf  = 2,
    max_features    = 'sqrt',
    random_state    = 42,
    n_jobs          = -1,
)


def train(use_db: bool = True):
    """Train the Random Forest baseline model and save it."""
    print('=' * 70)
    print('AgriGuard  |  Baseline Model  |  Random Forest')
    print('=' * 70)

    print('\n[1] Loading data ...')
    df = build_dataset(use_db=use_db, include_diary_features=False)
    if len(df) < 10:
        raise ValueError(f'Need >= 10 rows, got {len(df)}. '
                         'Check that the historical CSV exists.')

    print('\n[2] Preparing features ...')
    X, y, encoders, _ = prepare_features(df, include_diary=False)
    print(f'    Features ({len(X.columns)}): {list(X.columns)}')
    print(f'    Samples:  {len(X)}')

    from sklearn.model_selection import train_test_split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42
    )
    print(f'    Train: {len(X_train)}  |  Test: {len(X_test)}')

    print('\n[3] Training Random Forest ...')
    t0 = datetime.datetime.now()
    model = RandomForestRegressor(**RF_PARAMS)
    model.fit(X_train, y_train)
    train_secs = (datetime.datetime.now() - t0).total_seconds()

    print(f'    Done in {train_secs:.1f}s')

    print('\n[4] Evaluating ...')
    metrics = _evaluate(model, X_train, y_train, X_test, y_test, train_secs)
    _print_metrics(metrics)
    _print_importances(model, X.columns)

    print('\n[5] Saving model ...')
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    artifact = {
        'model':          model,
        'encoders':       encoders,
        'metrics':        metrics,
        'features':       list(X.columns),
        'model_type':     'RandomForestRegressor',
        'hyperparameters': RF_PARAMS,
        'feature_info':   _feature_info(),
        'trained_at':     datetime.datetime.now().isoformat(),
    }
    joblib.dump(artifact, MODEL_OUTPUT)
    print(f'    Saved to {MODEL_OUTPUT}')
    print('\n' + '=' * 70)
    print('Baseline training complete!')
    print('=' * 70)
    return metrics, list(X.columns)


def _evaluate(model, X_train, y_train, X_test, y_test, train_secs):
    y_pred_tr = model.predict(X_train)
    y_pred_te = model.predict(X_test)
    return {
        'r2_train':    float(r2_score(y_train, y_pred_tr)),
        'r2_test':     float(r2_score(y_test, y_pred_te)),
        'mae_test':    float(mean_absolute_error(y_test, y_pred_te)),
        'rmse_test':   float(np.sqrt(mean_squared_error(y_test, y_pred_te))),
        'mape_test':   float(mean_absolute_percentage_error(y_test, y_pred_te)) * 100,
        'n_train':     int(len(X_train)),
        'n_test':      int(len(X_test)),
        'train_secs':  round(train_secs, 1),
    }


def _print_metrics(m):
    print(f'    Train R²:  {m["r2_train"]:.4f}')
    print(f'    Test  R²:  {m["r2_test"]:.4f}')
    print(f'    Test MAE:  {m["mae_test"]:.1f} kg/ha')
    print(f'    Test RMSE: {m["rmse_test"]:.1f} kg/ha')
    print(f'    Test MAPE: {m["mape_test"]:.1f}%')
    print(f'    Train time:{m["train_secs"]}s')


def _print_importances(model, columns):
    imp = sorted(
        zip(columns, model.feature_importances_),
        key=lambda x: -x[1],
    )
    print('\n    Feature Importances:')
    for feat, val in imp:
        bar = '#' * int(val * 40)
        print(f'    {feat:35s} {bar:40s} {val:.4f}')


def _feature_info():
    return {
        'Area_Planted_ha':           'Farm area in hectares — larger farms can achieve scale efficiency',
        'Year':                      'Harvest year — captures technology improvement and climate drift',
        'Crop_encoded':              'Crop type — strongest single predictor (~66% importance)',
        'Region_encoded':            'Ghana region — different agro-ecological zones have distinct yield ceilings',
        'District_encoded':          'District — local soil type, microclimate, and market infrastructure',
        'national_fertilizer_kg_ha': 'Ghana national fertilizer use (kg/ha arable) — World Bank AG.CON.FERT.ZS. '
                                     'Captures aggregate input quality trends across years',
        'national_agri_land_km2':    'Ghana total agricultural land (km²) — World Bank AG.LND.AGRI.K2. '
                                     'Indicates land pressure and expansion/contraction of farming footprint',
    }


if __name__ == '__main__':
    train(use_db=True)
