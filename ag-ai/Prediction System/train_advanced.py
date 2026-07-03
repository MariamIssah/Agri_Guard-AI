"""
Advanced Model Training — AgriGuard Prediction System
=====================================================

Model:     Gradient Boosting Regressor (sklearn GradientBoostingRegressor)
Rationale: Sequential boosting — each new tree corrects the residual errors
           of all previous trees. Stronger regularisation than Random Forest,
           handles feature interactions better, and consistently outperforms
           RF on structured tabular data when tuned appropriately.

           Why Gradient Boosting over Random Forest (baseline)?
           ─────────────────────────────────────────────────────
           Random Forest trains trees INDEPENDENTLY and averages them
           (bagging → reduces variance). Gradient Boosting trains trees
           SEQUENTIALLY, each one fitting the GRADIENT of the loss of the
           ensemble so far (boosting → reduces both bias AND variance).
           The result is a stronger model at the cost of:
             - More hyperparameters to tune (learning rate, subsample, depth)
             - Slightly longer training time
             - More sensitive to noisy labels

           This is the industry-standard progression:
             Baseline (RF) → Advanced (GBM) → Deployment (best model)

Features:  Same 7 core features as the baseline model, ensuring a
           controlled, apples-to-apples comparison.

Output:    Prediction System/models/advanced_model.joblib
"""

import sys
import datetime
import numpy as np
import joblib
from pathlib import Path
from sklearn.ensemble import GradientBoostingRegressor, HistGradientBoostingRegressor
from sklearn.metrics import (
    mean_squared_error, mean_absolute_error,
    r2_score, mean_absolute_percentage_error,
)

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from data_prep import build_dataset, prepare_features

MODEL_DIR    = Path(__file__).resolve().parent / 'models'
MODEL_OUTPUT = MODEL_DIR / 'advanced_model.joblib'

# ── Hyperparameters ────────────────────────────────────────────────────────────
#
#  n_estimators  = 500
#    Why: GBM benefits from more rounds than RF because each tree is
#    intentionally weak (max_depth=4). 500 rounds with a small learning_rate
#    of 0.05 allows the model to learn slowly and precisely rather than
#    rushing to a local optimum.
#
#  max_depth  = 4
#    Why: Unlike RF which uses deep trees (depth=20) to capture interactions,
#    GBM works better with SHALLOW trees (called "stumps" at depth=1–3).
#    Shallow trees prevent the sequential model from overfitting to noisy
#    training rows. Each round contributes a small incremental improvement.
#    Depth=4 gives enough expressiveness for our 7 features.
#
#  learning_rate  = 0.05
#    Why: The shrinkage factor. A smaller value forces the model to take
#    many small steps (more rounds needed) but arrives at a more robust
#    solution. The trade-off: n_estimators must be proportionally higher.
#    0.05 with 500 rounds is a well-validated combination.
#
#  subsample  = 0.8
#    Why: Stochastic GBM — each tree is fitted on 80% of training rows
#    (sampled without replacement). This introduces randomness that prevents
#    overfitting and speeds up training. Analogous to bagging within GBM.
#
#  min_samples_leaf  = 4
#    Why: Prevents splits on very small groups. In GBM, noisy leaves are
#    more harmful than in RF because subsequent trees amplify their gradients.
#    Minimum 4 samples per leaf reduces this risk.
#
#  max_features  = 'sqrt'
#    Why: Column subsampling — each split considers sqrt(n_features) columns.
#    Decorrelates trees, just as in RF, and prevents the dominant feature
#    (Crop_encoded) from dominating every single split.
#
#  random_state  = 42
#    Why: Identical seed as the baseline ensures both models see the same
#    random splits, making the comparison statistically valid.

GBM_PARAMS = dict(
    n_estimators      = 500,
    max_depth         = 4,
    learning_rate     = 0.05,
    subsample         = 0.8,
    min_samples_leaf  = 4,
    max_features      = 'sqrt',
    loss              = 'squared_error',
    random_state      = 42,
)


def train(use_db: bool = True):
    """Train the Gradient Boosting advanced model and save it."""
    print('=' * 70)
    print('AgriGuard  |  Advanced Model  |  Gradient Boosting')
    print('=' * 70)

    print('\n[1] Loading data ...')
    df = build_dataset(use_db=use_db, include_diary_features=False)
    if len(df) < 10:
        raise ValueError(f'Need >= 10 rows, got {len(df)}.')

    print('\n[2] Preparing features ...')
    X, y, encoders, _ = prepare_features(df, include_diary=False)
    print(f'    Features ({len(X.columns)}): {list(X.columns)}')
    print(f'    Samples:  {len(X)}')

    from sklearn.model_selection import train_test_split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42
    )
    print(f'    Train: {len(X_train)}  |  Test: {len(X_test)}')

    print('\n[3] Training Gradient Boosting ...')
    print('    (500 rounds × depth-4 trees, lr=0.05 — this may take ~30s)')
    t0 = datetime.datetime.now()
    model = GradientBoostingRegressor(**GBM_PARAMS)
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
        'model':           model,
        'encoders':        encoders,
        'metrics':         metrics,
        'features':        list(X.columns),
        'model_type':      'GradientBoostingRegressor',
        'hyperparameters': GBM_PARAMS,
        'feature_info':    _feature_info(),
        'trained_at':      datetime.datetime.now().isoformat(),
    }
    joblib.dump(artifact, MODEL_OUTPUT)
    print(f'    Saved to {MODEL_OUTPUT}')
    print('\n' + '=' * 70)
    print('Advanced training complete!')
    print('=' * 70)
    return metrics, list(X.columns)


def _evaluate(model, X_train, y_train, X_test, y_test, train_secs):
    y_pred_tr = model.predict(X_train)
    y_pred_te = model.predict(X_test)
    return {
        'r2_train':   float(r2_score(y_train, y_pred_tr)),
        'r2_test':    float(r2_score(y_test, y_pred_te)),
        'mae_test':   float(mean_absolute_error(y_test, y_pred_te)),
        'rmse_test':  float(np.sqrt(mean_squared_error(y_test, y_pred_te))),
        'mape_test':  float(mean_absolute_percentage_error(y_test, y_pred_te)) * 100,
        'n_train':    int(len(X_train)),
        'n_test':     int(len(X_test)),
        'train_secs': round(train_secs, 1),
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
        'Area_Planted_ha':           'Farm area in hectares',
        'Year':                      'Harvest year',
        'Crop_encoded':              'Crop type (label-encoded)',
        'Region_encoded':            'Ghana region (label-encoded)',
        'District_encoded':          'District (label-encoded)',
        'national_fertilizer_kg_ha': 'Ghana national fertilizer use (kg/ha) — World Bank',
        'national_agri_land_km2':    'Ghana agricultural land (km²) — World Bank',
    }


if __name__ == '__main__':
    train(use_db=True)
