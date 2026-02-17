from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class RideParticipantRead(BaseModel):
    participant_id: UUID
    ride_id: UUID
    user_id: UUID
    joined_at: datetime
