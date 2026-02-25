"""
Pydantic schemas for saved addresses.
"""
from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field


class AddressCreate(BaseModel):
    """Create a new saved address."""
    label: str = Field(..., min_length=1, max_length=50, description="e.g., Home, College, Library")
    address: str = Field(..., min_length=5, max_length=500, description="Full text address")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    is_default: bool = False


class AddressRead(BaseModel):
    """Saved address response."""
    id: UUID
    label: str
    address: str
    latitude: float
    longitude: float
    is_default: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class AddressUpdate(BaseModel):
    """Update a saved address (all fields optional)."""
    label: Optional[str] = Field(None, min_length=1, max_length=50)
    address: Optional[str] = Field(None, min_length=5, max_length=500)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    is_default: Optional[bool] = None
