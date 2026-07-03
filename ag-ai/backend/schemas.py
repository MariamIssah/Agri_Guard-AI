"""Pydantic request/response schemas for the AgriGuard API."""

from typing import Optional, Union
from pydantic import BaseModel, Field


class FarmDataPayload(BaseModel):
    farmer_id: str
    crop_type: str
    area_hectares: float = Field(gt=0)
    region: Optional[str] = None
    district: Optional[str] = None
    season: Optional[str] = None
    soil_type: Optional[str] = None
    planting_date: Optional[str] = None
    weather_record: Optional[dict] = None
    notes: Optional[str] = None


class PredictionPayload(BaseModel):
    crop: str
    region: str
    area: float = Field(gt=0)
    district: Optional[str] = None
    year: Optional[int] = None
    symptoms: Optional[str] = None
    weather: Optional[Union[str, dict]] = None
    weather_record: Optional[Union[str, dict]] = None
    quality_score: Optional[float] = None
    observed_disease: Optional[str] = None


class PreHarvestPayload(BaseModel):
    farmer_id: str
    crop: str
    region: str
    area_hectares: float = Field(gt=0)
    district: Optional[str] = None
    planting_date: Optional[str] = None
    expected_harvest_date: Optional[str] = None
    year: Optional[int] = None
    symptoms: Optional[str] = None
    weather: Optional[Union[str, dict]] = None
    quality_score: Optional[float] = None
    observed_disease: Optional[str] = None


class PostHarvestPayload(BaseModel):
    farmer_id: str
    crop: str
    region: str
    area_hectares: float = Field(gt=0)
    district: Optional[str] = None
    actual_yield_kg: float = Field(gt=0)
    actual_production_tonnes: Optional[float] = None
    harvest_date: Optional[str] = None
    year: Optional[int] = None
    quality_score: Optional[float] = None
    notes: Optional[str] = None


class BuyerQueryPayload(BaseModel):
    crop: Optional[str] = None
    region: Optional[str] = None
    district: Optional[str] = None
    year: Optional[int] = None


class DiagnosePayload(BaseModel):
    crop: str
    region: str
    symptoms: Optional[str] = None
    weather: Optional[Union[str, dict]] = None
    weather_record: Optional[Union[str, dict]] = None
    quality_score: Optional[float] = None
    observed_disease: Optional[str] = None
