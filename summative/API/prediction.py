"""
Solar Device Price API - predicts what a Kenyan household pays upfront for a solar device.
The model comes from linear_regression/multivariate.ipynb.

Run locally with: uv run uvicorn prediction:app --reload
"""

from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from retrain import load_new_data, retrain_model

# load the model once at startup
MODEL_PATH = Path(__file__).parent / "best_model.pkl"
pipeline = joblib.load(MODEL_PATH)


def predict_price(row: dict, model=None) -> float:
    """Predicted upfront price in KES for one device."""
    model = model if model is not None else joblib.load(MODEL_PATH)
    X_one = pd.DataFrame([row])
    log_price = model.predict(X_one)[0]
    # model was trained on log price
    return float(np.exp(log_price))


app = FastAPI(
    title="Solar Device Price API",
    description=(
        "Predicts the upfront price (KES) a Kenyan household pays for a solar device, so buyers and "
        "NGOs can judge whether a quoted price is fair. Model: SGDRegressor trained on the World Bank "
        "Multi-Tier Framework Energy Survey, Kenya 2016-2018."
    ),
    version="1.0.0",
)

# CORS: only Swagger on Render and the local Flutter web build can call this from a browser.
# The mobile app isn't a browser, so CORS doesn't affect it.
ALLOWED_ORIGINS = [
    "https://linear-regression-model-k2sr.onrender.com",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
    allow_credentials=False,
)

County = Literal[
    "Baringo", "Bomet", "Bungoma", "Busia", "Elgeyo Marakwet", "Embu", "Garissa", "Homa Bay",
    "Isiolo", "Kajiado", "Kakamega", "Kericho", "Kiambu", "Kilifi", "Kirinyaga", "Kisii", "Kisumu",
    "Kitui", "Kwale", "Laikipia", "Lamu", "Machakos", "Makueni", "Mandera", "Marsabit", "Meru",
    "Migori", "Mombasa", "Muranga", "Nairobi", "Nakuru", "Nandi", "Narok", "Nyamira", "Nyandarua",
    "Nyeri", "Samburu", "Siaya", "Taita Taveta", "Tana-River", "Tharaka-Nithi", "Trans Nzoia",
    "Turkana", "Uasin Gishu", "Vihiga", "Wajir", "West Pokot",
]
YesNo = Literal["Yes", "No"]


class DeviceInput(BaseModel):
    # no type coercion, no extra fields
    model_config = ConfigDict(
        strict=True,
        extra="forbid",
        json_schema_extra={
            "examples": [{
                "device_type": "Solar Lantern",
                "acquisition": "Bought, fully paid",
                "county": "Kisumu",
                "locality": "Rural",
                "owns_dwelling": "Yes",
                "grid_connected": "No",
                "has_bank_account": "No",
                "years_owned": 2.0,
                "rooms": 3,
                "mobile_phones": 2,
            }]
        },
    )

    device_type: Literal["Solar Lantern", "Solar lighting System", "Solar home system (Solar PV system)"] = Field(
        description="Type of solar device")
    acquisition: Literal["Bought, fully paid", "Bought, under installment"] = Field(
        description="How the device is being bought")
    county: County = Field(
        description=("Kenyan county, spelled as in the survey. Nakuru and Mombasa do not appear "
                     "in the training data, so they get the model's estimate for rare counties."))
    locality: Literal["Rural", "Urban"] = Field(
        description="Rural or urban area")
    owns_dwelling: YesNo = Field(
        description="Does the household own its home?")
    grid_connected: YesNo = Field(
        description="Is the household connected to the national grid?")
    has_bank_account: YesNo = Field(
        description="Does anyone in the household have a bank account?")
    years_owned: float = Field(
        gt=0, le=30, description="Years the household has owned the device (more than 0, up to 30)")
    rooms: int = Field(ge=1, le=25, description="Rooms in the home, 1 to 25")
    mobile_phones: int = Field(
        ge=0, le=10, description="Mobile phones in the household, 0 to 10")


class PredictionOutput(BaseModel):
    predicted_price_kes: float
    model: str


@app.get("/")
def home():
    return {"message": "Solar Device Price API. Open /docs to try it."}


@app.post("/predict", response_model=PredictionOutput)
def predict(data: DeviceInput):
    price = predict_price(data.model_dump(), model=pipeline)
    return {"predicted_price_kes": round(price, 2), "model": type(pipeline.named_steps["model"]).__name__}


@app.post("/retrain")
async def retrain(file: UploadFile = File(..., description="CSV with the 10 input columns plus price_kes")):
    global pipeline
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(
            status_code=400, detail="Please upload a .csv file.")

    try:
        new_df = load_new_data(await file.read())
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    pipeline, summary = retrain_model(pipeline, new_df)
    # only survives until Render restarts, which is fine for this project
    joblib.dump(pipeline, MODEL_PATH)
    return {"message": "Model retrained and now in use.", **summary}
