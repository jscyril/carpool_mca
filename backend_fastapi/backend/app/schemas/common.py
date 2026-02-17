from pydantic import BaseModel, Field, model_validator
from uuid import UUID
from datetime import datetime
from typing import Optional, Any
from geoalchemy2.shape import to_shape
from geoalchemy2.elements import WKBElement

class LocationPoint(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

    @model_validator(mode='before')
    @classmethod
    def parse_wkb(cls, v: Any) -> Any:
        if isinstance(v, WKBElement):
            point = to_shape(v)
            return {"latitude": point.y, "longitude": point.x}
        return v

class TimestampMixin(BaseModel):
    created_at: Optional[datetime] = None
