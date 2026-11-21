"""
Retraining for the price API.

The best model is an SGDRegressor, so instead of training from scratch we keep the fitted
preprocessing and just continue training with partial_fit.

I mix the original training rows (train_data.csv) in with the new ones. When I trained on the
new rows alone, the model started forgetting the original data - after five uploads the MSE on
the original set went from 0.79 to 0.96. With the mix it stays around 0.80.
"""

import copy
import io
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import mean_squared_error

FEATURES = [
    "device_type", "acquisition", "county", "locality", "owns_dwelling",
    "grid_connected", "has_bank_account", "years_owned", "rooms", "mobile_phones",
]
NUMERIC = ["years_owned", "rooms", "mobile_phones"]
TARGET = "price_kes"
REQUIRED_COLUMNS = FEATURES + [TARGET]

# saved from the notebook
TRAIN_DATA_PATH = Path(__file__).parent / "train_data.csv"


def _clean(df: pd.DataFrame) -> pd.DataFrame:
    """Keep the needed columns, coerce numbers and drop rows without a usable price."""
    df = df[REQUIRED_COLUMNS].copy()
    df[TARGET] = pd.to_numeric(df[TARGET], errors="coerce")
    for col in NUMERIC:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    # need a positive finite price to take the log
    return df[np.isfinite(df[TARGET]) & (df[TARGET] > 0)]


def load_new_data(raw_bytes: bytes) -> pd.DataFrame:
    """Read the uploaded CSV. Raises ValueError if it can't be used."""
    try:
        df = pd.read_csv(io.BytesIO(raw_bytes))
    except Exception:
        raise ValueError("The file could not be read as a CSV.")

    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"The CSV is missing these columns: {missing}")

    df = _clean(df)
    if df.empty:
        raise ValueError(f"No rows have a valid {TARGET} above 0.")
    return df


def retrain_model(pipeline, new_df: pd.DataFrame, epochs: int = 20):
    """Continue training on original + new rows. Works on a copy so a failure leaves the live model alone."""
    pipeline = copy.deepcopy(pipeline)
    prep = pipeline.named_steps["prep"]
    model = pipeline.named_steps["model"]

    original_df = _clean(pd.read_csv(TRAIN_DATA_PATH))
    combined_df = pd.concat([original_df, new_df], ignore_index=True)

    X_new_t, y_new = prep.transform(new_df[FEATURES]), np.log(new_df[TARGET].to_numpy())
    X_orig_t, y_orig = prep.transform(original_df[FEATURES]), np.log(original_df[TARGET].to_numpy())
    X_all_t, y_all = prep.transform(combined_df[FEATURES]), np.log(combined_df[TARGET].to_numpy())

    before_new = mean_squared_error(y_new, model.predict(X_new_t))
    before_orig = mean_squared_error(y_orig, model.predict(X_orig_t))

    rng = np.random.default_rng(42)
    for _ in range(epochs):
        order = rng.permutation(len(X_all_t))
        model.partial_fit(X_all_t[order], y_all[order])

    after_new = mean_squared_error(y_new, model.predict(X_new_t))
    after_orig = mean_squared_error(y_orig, model.predict(X_orig_t))

    summary = {
        "new_rows_used": int(len(new_df)),
        "original_rows_used": int(len(original_df)),
        "epochs": epochs,
        # log-price MSE, same as the notebook
        "mse_on_new_rows_before": round(float(before_new), 4),
        "mse_on_new_rows_after": round(float(after_new), 4),
        "mse_on_original_training_data_before": round(float(before_orig), 4),
        "mse_on_original_training_data_after": round(float(after_orig), 4),
    }
    return pipeline, summary
