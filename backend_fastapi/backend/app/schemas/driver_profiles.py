"""
Pydantic schemas for driver profiles.
"""
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field


class DriverProfileCreate(BaseModel):
    """Create or upsert a driver profile."""
    vehicle_id: UUID
    daily_seat_limit: int = Field(..., ge=1, le=10)


class DriverProfileRead(BaseModel):
    """Driver profile response with vehicle info."""
    user_id: UUID
    vehicle_id: UUID
    daily_seat_limit: int
    is_driver_active: bool
    vehicle_number: Optional[str] = None
    
    class Config:
        from_attributes = True


class DriverProfileUpdate(BaseModel):
    """Partial update for driver profile."""
    vehicle_id: Optional[UUID] = None
    daily_seat_limit: Optional[int] = Field(None, ge=1, le=10)
    is_driver_active: Optional[bool] = None
