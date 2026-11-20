"""
Retraining logic for the solar device price API.

The saved model is a scikit-learn Pipeline with two steps:
  "prep"  - imputers, StandardScaler and OneHotEncoder, fitted on the original training data
  "model" - an SGDRegressor that predicts the log of the price

Because the best model is SGDRegressor, new data does not require training from scratch:
the existing model continues learning with partial_fit, as the brief specifies for this case.
The preprocessing is kept as it is, so the new rows are scaled and encoded exactly like the
data the model originally learned from.

Each partial_fit pass covers the new rows together with the original training rows
(train_data.csv, real survey rows saved by the notebook). Training on the new rows alone
made the model drift towards them and forget the original data: in testing, five uploads
of new_data.csv raised the MSE on the original training data from 0.79 to 0.96. Mixing in
the original rows keeps it at about 0.80 while the model still learns from the new rows.
"""

import copy
import io
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import mean_squared_error

# The 10 model inputs and the target, matching the columns of the training data
FEATURES = [
    "device_type", "acquisition", "county", "locality", "owns_dwelling",
    "grid_connected", "has_bank_account", "years_owned", "rooms", "mobile_phones",
]
NUMERIC = ["years_owned", "rooms", "mobile_phones"]
TARGET = "price_kes"
REQUIRED_COLUMNS = FEATURES + [TARGET]

# Raw training rows saved by the notebook (cell 34); loaded from the repo on every retrain
TRAIN_DATA_PATH = Path(__file__).parent / "train_data.csv"


def _clean(df: pd.DataFrame) -> pd.DataFrame:
    """Keep the required columns, make numbers numeric and drop rows without a usable price."""
    df = df[REQUIRED_COLUMNS].copy()
    df[TARGET] = pd.to_numeric(df[TARGET], errors="coerce")
    for col in NUMERIC:
        # text becomes blank; blanks are filled by the pipeline's imputer
        df[col] = pd.to_numeric(df[col], errors="coerce")
    # a finite price above 0 is needed to learn from (np.log fails on 0, negatives and infinity)
    return df[np.isfinite(df[TARGET]) & (df[TARGET] > 0)]


def load_new_data(raw_bytes: bytes) -> pd.DataFrame:
    """Read an uploaded CSV and keep only usable rows. Raises ValueError with a readable message."""
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
    """Continue training the saved SGDRegressor with partial_fit on the original rows plus the new rows.

    Returns the updated pipeline and a summary. The input pipeline is not modified, so if anything
    fails part-way the API keeps serving the previous model.
    """
    pipeline = copy.deepcopy(pipeline)
    prep = pipeline.named_steps["prep"]
    model = pipeline.named_steps["model"]

    original_df = _clean(pd.read_csv(TRAIN_DATA_PATH))
    combined_df = pd.concat([original_df, new_df], ignore_index=True)

    # reuse the original scaler and encoder; the model predicts log price
    X_new_t, y_new = prep.transform(new_df[FEATURES]), np.log(new_df[TARGET].to_numpy())
    X_orig_t, y_orig = prep.transform(original_df[FEATURES]), np.log(original_df[TARGET].to_numpy())
    X_all_t, y_all = prep.transform(combined_df[FEATURES]), np.log(combined_df[TARGET].to_numpy())

    before_new = mean_squared_error(y_new, model.predict(X_new_t))
    before_orig = mean_squared_error(y_orig, model.predict(X_orig_t))

    rng = np.random.default_rng(42)
    # one partial_fit call = one pass (epoch) over the rows, reshuffled each time
    for _ in range(epochs):
        order = rng.permutation(len(X_all_t))
        model.partial_fit(X_all_t[order], y_all[order])

    after_new = mean_squared_error(y_new, model.predict(X_new_t))
    after_orig = mean_squared_error(y_orig, model.predict(X_orig_t))

    summary = {
        "new_rows_used": int(len(new_df)),
        "original_rows_used": int(len(original_df)),
        "epochs": epochs,
        # MSE in log-price units, the same units as the notebook
        "mse_on_new_rows_before": round(float(before_new), 4),
        "mse_on_new_rows_after": round(float(after_new), 4),
        "mse_on_original_training_data_before": round(float(before_orig), 4),
        "mse_on_original_training_data_after": round(float(after_orig), 4),
    }
    return pipeline, summary
