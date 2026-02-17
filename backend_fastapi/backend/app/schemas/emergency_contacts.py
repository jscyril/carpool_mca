"""
Emergency contact schemas.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional


class EmergencyContactCreate(BaseModel):
    contact_name: str = Field(..., max_length=100)
    contact_phone: str = Field(..., max_length=15)
    relationship: str = Field(..., max_length=50)


class EmergencyContactRead(EmergencyContactCreate):
    contact_id: UUID
    user_id: UUID

    class Config:
        from_attributes = True


class EmergencyContactUpdate(BaseModel):
    contact_name: Optional[str] = Field(None, max_length=100)
    contact_phone: Optional[str] = Field(None, max_length=15)
    relationship: Optional[str] = Field(None, max_length=50)
