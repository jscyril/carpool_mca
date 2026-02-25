from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from .enums import VehicleTypeEnum

class VehicleBase(BaseModel):
    vehicle_type: VehicleTypeEnum
    vehicle_number: str

class VehicleCreate(VehicleBase):
    pass  # user_id inferred from auth token

class VehicleRead(VehicleBase):
    vehicle_id: UUID
    user_id: UUID
    created_at: datetime
    
    class Config:
        from_attributes = True
