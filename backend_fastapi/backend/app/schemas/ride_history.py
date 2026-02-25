from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class RideHistoryRead(BaseModel):
    history_id: UUID
    ride_id: UUID
    driver_id: UUID
    passenger_id: UUID
    completed_at: datetime
