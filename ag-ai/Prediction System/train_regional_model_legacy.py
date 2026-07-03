"""
Train yield prediction model using regional/district historical data.

Input: agri_guard_training_data_regional.csv
Output: models/regional_yield_model.joblib

This model supports:
- Farm-level predictions (input: crop, region, district, area)
- Regional forecasting (aggregate by region/district)
"""

import pandas as pd
import numpy as np
import joblib
import sys
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
from pathlib import Path

MODEL_OUTPUT = 'models/regional_yield_model.joblib'
DATA_INPUT = 'agri_guard_training_data_regional.csv'


def prepare_training_data(df):
    """Prepare data for training with proper feature engineering."""
    print("Preparing training data...")
    
    df = df.copy()
    
    # Filter: keep only complete records
    df = df[df['Yield_kg_per_ha'].notna() & df['Area_Planted_ha'].notna()].copy()
    print(f"  Complete records: {len(df)}")
    
    # Create feature set
    features_to_use = ['Area_Planted_ha', 'Crop', 'Region', 'District', 'Year']
    df = df[features_to_use + ['Yield_kg_per_ha']].copy()
    
    # Feature engineering
    X = df[features_to_use].copy()
    y = df['Yield_kg_per_ha'].astype(float)
    
    # Encode categorical features
    encoders = {}
    categorical_cols = ['Crop', 'Region', 'District']
    
    for col in categorical_cols:
        le = LabelEncoder()
        # Handle NaN by filling with 'Unknown' first
        X[col] = X[col].fillna('Unknown')
        X[col + '_encoded'] = le.fit_transform(X[col].astype(str))
        encoders[col] = le
    
    # Build feature matrix: numerical + encoded categoricals
    numerical_features = ['Area_Planted_ha', 'Year']
    encoded_features = [f"{col}_encoded" for col in categorical_cols]
    
    X_final = X[numerical_features + encoded_features].copy()
    X_final.columns = numerical_features + encoded_features
    
    # Handle any remaining NaN
    X_final = X_final.fillna(X_final.mean(numeric_only=True))
    
    # Remove rows with NaN in y
    mask = y.notna()
    X_final = X_final[mask].reset_index(drop=True)
    y = y[mask].reset_index(drop=True)
    
    print(f"  Final training set: {len(X_final)} records")
    print(f"  Features: {list(X_final.columns)}")
    
    return X_final, y, encoders


def train_model(X, y):
    """Train RandomForest yield prediction model."""
    print("\nTraining RandomForest model...")
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    print(f"  Training set: {len(X_train)} records")
    print(f"  Test set: {len(X_test)} records")
    
    # Train model
    model = RandomForestRegressor(
        n_estimators=150,
        max_depth=20,
        min_samples_split=5,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred_train = model.predict(X_train)
    y_pred_test = model.predict(X_test)
    
    mse_train = mean_squared_error(y_train, y_pred_train)
    mse_test = mean_squared_error(y_test, y_pred_test)
    r2_train = r2_score(y_train, y_pred_train)
    r2_test = r2_score(y_test, y_pred_test)
    mae_test = mean_absolute_error(y_test, y_pred_test)
    
    print(f"\n  Training Results:")
    print(f"    Train MSE: {mse_train:.2f}, R²: {r2_train:.4f}")
    print(f"    Test MSE:  {mse_test:.2f}, R²: {r2_test:.4f}")
    print(f"    Test MAE:  {mae_test:.2f} kg/ha")
    
    # Feature importance
    feature_importance = pd.DataFrame({
        'Feature': X_train.columns,
        'Importance': model.feature_importances_
    }).sort_values('Importance', ascending=False)
    
    print(f"\n  Top 5 Features:")
    for idx, row in feature_importance.head(5).iterrows():
        print(f"    {row['Feature']}: {row['Importance']:.4f}")
    
    return model, {
        'mse_train': mse_train,
        'mse_test': mse_test,
        'r2_train': r2_train,
        'r2_test': r2_test,
        'mae_test': mae_test
    }


def save_model(model, encoders, metrics):
    """Save model and metadata."""
    Path('models').mkdir(exist_ok=True)
    
    artifact = {
        'model': model,
        'encoders': encoders,
        'metrics': metrics,
        'features': ['Area_Planted_ha', 'Year', 'Crop_encoded', 'Region_encoded', 'District_encoded'],
        'feature_info': {
            'Area_Planted_ha': 'Hectares (numeric)',
            'Year': 'Year (numeric)',
            'Crop_encoded': 'Encoded crop type',
            'Region_encoded': 'Encoded region',
            'District_encoded': 'Encoded district'
        }
    }
    
    joblib.dump(artifact, MODEL_OUTPUT)
    print(f"\n✓ Model saved to {MODEL_OUTPUT}")


def main():
    print("=" * 70)
    print("Training Regional/District Yield Prediction Model")
    print("=" * 70)
    
    # Load data
    print(f"\nLoading {DATA_INPUT}...")
    df = pd.read_csv(DATA_INPUT)
    print(f"  Total records: {len(df)}")
    
    # Prepare training data
    X, y, encoders = prepare_training_data(df)
    
    # Train model
    model, metrics = train_model(X, y)
    
    # Save model
    save_model(model, encoders, metrics)
    
    print("\n" + "=" * 70)
    print("Training complete!")
    print("=" * 70)


if __name__ == '__main__':
    main()
