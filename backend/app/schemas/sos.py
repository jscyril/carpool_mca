"""
SOS schemas.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class SOSAlertCreate(BaseModel):
    """Create an SOS alert."""
    ride_id: UUID
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)


class SOSAlertRead(BaseModel):
    """SOS alert response."""
    alert_id: UUID
    user_id: UUID
    ride_id: UUID
    triggered_at: datetime

    class Config:
        from_attributes = True
