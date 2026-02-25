from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import List, Optional

class FaceDataBase(BaseModel):
    face_embedding: List[float]

class FaceDataCreate(FaceDataBase):
    user_id: UUID

class FaceDataRead(FaceDataBase):
    user_id: UUID
    last_verified_at: Optional[datetime]
