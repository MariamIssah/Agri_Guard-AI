import argparse
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
import joblib


def load_data(path):
    df = pd.read_csv(path)
    return df


def prepare_features(df):
    # Use only rows with known target
    df = df.copy()
    df = df[df['yield_kg_per_ha'].notna()]

    # Select features (numeric columns + crop_type one-hot)
    features = ['area_planted_ha', 'fertilizer_kg_per_ha', 'agricultural_land_sq_km']
    X_num = df[features]

    # One-hot encode crop_type
    X_cat = pd.get_dummies(df['crop_type'].astype(str), prefix='crop')

    X = pd.concat([X_num.reset_index(drop=True), X_cat.reset_index(drop=True)], axis=1)
    y = df['yield_kg_per_ha'].astype(float).reset_index(drop=True)
    # Drop rows with any NaNs in X
    mask = X.notna().all(axis=1)
    X = X[mask]
    y = y[mask]
    return X, y


def train_model(X, y):
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    preds = model.predict(X_test)
    mse = mean_squared_error(y_test, preds)
    r2 = r2_score(y_test, preds)
    return model, mse, r2


def main():
    parser = argparse.ArgumentParser(description='Train yield model from enhanced dataset')
    parser.add_argument('--input', '-i', default='agri_guard_historical_training_data_enhanced.csv')
    parser.add_argument('--output', '-o', default='models/yield_model.joblib')
    args = parser.parse_args()

    df = load_data(args.input)
    X, y = prepare_features(df)
    if X.shape[0] == 0:
        print('No training rows after feature preparation. Exiting.')
        return

    model, mse, r2 = train_model(X, y)

    # Ensure models directory exists
    import os
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    joblib.dump({'model': model, 'features': list(X.columns)}, args.output)

    print(f'Trained model saved to {args.output}')
    print(f'MSE: {mse:.4f}, R2: {r2:.4f}')


if __name__ == '__main__':
    main()
