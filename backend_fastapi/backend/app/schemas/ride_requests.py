"""
Pydantic schemas for ride requests.
"""
from datetime import datetime
from typing import Literal, Optional
from uuid import UUID
from pydantic import BaseModel


class RideRequestCreate(BaseModel):
    """Request to join a ride. ride_id from path, passenger_id from auth."""
    pass


class RideRequestRead(BaseModel):
    """Ride request response."""
    request_id: UUID
    ride_id: UUID
    passenger_id: UUID
    request_status: str
    requested_at: datetime
    
    class Config:
        from_attributes = True


class RideRequestAction(BaseModel):
    """Driver action on a ride request."""
    action: Literal["accept", "reject"]


class RideRequestWithUser(RideRequestRead):
    """Ride request with passenger details (for driver view)."""
    passenger_name: str
    passenger_phone: str
