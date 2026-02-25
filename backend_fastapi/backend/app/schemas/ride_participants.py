from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional

class RideParticipantRead(BaseModel):
    participant_id: UUID
    ride_id: UUID
    user_id: UUID
    pickup_lat: Optional[float] = None
    pickup_lng: Optional[float] = None
    pickup_address: Optional[str] = None
    pickup_otp: Optional[str] = None
    is_picked_up: bool = False
    joined_at: datetime

    class Config:
        from_attributes = True
