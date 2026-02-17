from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class FareEstimateRead(BaseModel):
    estimate_id: UUID
    ride_id: UUID
    distance_km: float
    estimated_fare: float
    calculated_at: datetime
