"""
Fare schemas for estimation and splitting.
"""
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class FareEstimateRead(BaseModel):
    """Fare estimate for a ride."""
    estimate_id: UUID
    ride_id: UUID
    distance_km: float
    estimated_fare: float
    calculated_at: datetime

    class Config:
        from_attributes = True


class FareSplitRead(BaseModel):
    """Fare split among ride participants."""
    total_fare: float
    distance_km: float
    participant_count: int
    per_person: float
