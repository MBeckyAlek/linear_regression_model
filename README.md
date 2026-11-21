# Electra: Solar Device Price Prediction

**Mission:** Expand access to affordable, clean energy for off-grid households in Kenya.
**Problem:** Solar device prices vary widely, and buyers rarely know if a quote is fair. Electra predicts the upfront price (KES) a household pays for a solar lantern, lighting system or home system, so buyers and NGOs can judge a quote before paying.

## Dataset

**Kenya Multi-Tier Energy Access Tracking Framework (MTF) Survey 2016–2018**, produced by ESMAP and published by the World Bank: [microdata.worldbank.org/index.php/catalog/3703](https://microdata.worldbank.org/index.php/catalog/3703) (also on [ENERGYDATA.INFO](https://energydata.info/dataset/kenya-multi-tier-framework-mtf-survey)).

A nationally representative household survey on energy access. I joined the solar device roster (1,909 devices) to the household survey (4,590 households, 773 variables) on the household ID. After removing devices with no price or device type, **1,485 devices** remain, with **10 features** (7 categorical: device type, payment, county, area, home ownership, grid connection, bank account; 3 numeric: years owned, rooms, mobile phones). The target is the price paid in KES, modelled as log price because raw prices are heavily skewed.

## API

**Swagger UI:** https://linear-regression-model-k2sr.onrender.com/docs

| Route | Method | What it does |
|---|---|---|
| `/predict` | POST | Takes the 10 inputs and returns the predicted price in KES |
| `/retrain` | POST | Takes an uploaded CSV of new data, continues training the model and starts using it |
| `/docs` | GET | Swagger UI |

The free Render service sleeps after 15 minutes without traffic, so the first request can take up to a minute.

## Video demo

**YouTube:** [ADD YOUR YOUTUBE LINK HERE]

## Run the mobile app

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable channel) and Android Studio with an Android emulator. Check the setup with:
   ```bash
   flutter doctor
   ```
2. Clone the repository and go to the app folder:
   ```bash
   git clone https://github.com/MBeckyAlek/linear_regression_model.git
   cd linear_regression_model/summative/FlutterApp
   ```
3. Install the dependencies:
   ```bash
   flutter pub get
   ```
4. Start an emulator from Android Studio (Device Manager), or list and launch one from the terminal:
   ```bash
   flutter emulators
   flutter emulators --launch <emulator_id>
   ```
   A real Android phone with USB debugging turned on also works.
5. Run the app:
   ```bash
   flutter run
   ```
6. Fill in the 10 fields and press **Predict**. The predicted price appears below the button. A missing, wrong or out-of-range value shows an error message in the same place. The sun/moon button in the header switches between light and dark mode.

---

## Model summary

Four scikit-learn models were trained in [`multivariate.ipynb`](summative/linear_regression/multivariate.ipynb) and compared on the same test set (MSE in log-price units):

| Model | Train MSE | Test MSE |
|---|---|---|
| **SGDRegressor (saved)** | 0.791 | **0.606** |
| LinearRegression | 0.779 | 0.623 |
| RandomForestRegressor | 0.738 | 0.632 |
| DecisionTreeRegressor | 0.771 | 0.666 |

Always predicting the average gives a test MSE of 1.324, so the saved model explains about 54% of the variation in log price. Device type is by far the strongest predictor, followed by county.

## Run the API locally

Requires [uv](https://docs.astral.sh/uv/).

```bash
cd summative/API
uv run uvicorn prediction:app --reload
```

Then open http://127.0.0.1:8000/docs.

## Repository structure

```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml
    ├── uv.lock
    ├── linear_regression/
    │   └── multivariate.ipynb      # data, models, plots, saved model
    ├── API/
    │   ├── prediction.py           # FastAPI app: /predict, /retrain, CORS
    │   ├── retrain.py              # retraining with partial_fit
    │   ├── best_model.pkl          # saved pipeline (preprocessing + SGDRegressor)
    │   ├── train_data.csv          # original training rows
    │   ├── new_data.csv            # held-out survey rows for the /retrain demo
    │   ├── requirements.txt
    │   ├── pyproject.toml
    │   └── uv.lock
    └── FlutterApp/                 # Electra mobile app
```
