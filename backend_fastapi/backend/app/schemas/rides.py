from pydantic import BaseModel, Field
from uuid import UUID
from datetime import date, time, datetime
from typing import List, Optional
from .common import LocationPoint
from .enums import RideStatusEnum, AllowedGenderEnum


class RideBase(BaseModel):
    start_location: LocationPoint
    end_location: LocationPoint
    start_address: str
    end_address: str
    ride_date: date
    ride_time: time
    available_seats: int = Field(..., ge=0)
    allowed_gender: AllowedGenderEnum
    allowed_community: Optional[str] = None
    estimated_fare: Optional[float] = None

class RideCreate(RideBase):
    vehicle_id: UUID
    # driver_id inferred from auth token

class RideRead(RideBase):
    ride_id: UUID
    status: RideStatusEnum
    created_at: datetime

    class Config:
        from_attributes = True


class RideParticipantDetailRead(BaseModel):
    """Confirmed ride participant with user details and pickup info."""
    participant_id: UUID
    user_id: UUID
    full_name: str
    phone_number: str
    pickup_lat: Optional[float] = None
    pickup_lng: Optional[float] = None
    pickup_address: Optional[str] = None
    is_picked_up: bool = False
    pickup_otp: Optional[str] = None
    joined_at: datetime

    class Config:
        from_attributes = True


class RideDetailRead(RideRead):
    """Extended ride details with driver info and participants."""
    driver_name: Optional[str] = None
    vehicle_number: Optional[str] = None
    participants: List[RideParticipantDetailRead] = []
    pickup_otp: Optional[str] = None  # ride-level OTP (legacy)


class RideSearchResult(RideRead):
    """Ride search result with distance from search point."""
    distance_km: float = Field(..., description="Distance from search point in km")


class RideStatusUpdate(BaseModel):
    """Request to update ride status."""
    status: RideStatusEnum


class OtpVerifyRequest(BaseModel):
    """Driver submits OTP to confirm rider pickup."""
    otp: str = Field(..., min_length=4, max_length=4)
    participant_id: Optional[UUID] = None  # specify which rider to verify
