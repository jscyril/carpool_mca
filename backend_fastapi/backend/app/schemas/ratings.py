"""
Rating schemas for post-ride ratings.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional


class RatingCreate(BaseModel):
    """Create a post-ride rating."""
    rated_user_id: UUID
    rating_value: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class RatingRead(BaseModel):
    """Rating response."""
    rating_id: UUID
    ride_id: UUID
    rater_id: UUID
    rated_user_id: UUID
    rating_value: int
    comment: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class UserRatingSummary(BaseModel):
    """User's aggregated rating summary."""
    user_id: UUID
    average_rating: float
    total_ratings: int
