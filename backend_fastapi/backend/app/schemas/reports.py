"""
Report schemas for user reports.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional


class ReportCreate(BaseModel):
    """Create a user report."""
    ride_id: UUID
    reported_user_id: UUID
    comment: str = Field(..., min_length=10, max_length=500)


class ReportRead(BaseModel):
    """Report response."""
    report_id: UUID
    ride_id: UUID
    reporter_id: UUID
    reported_user_id: UUID
    comment: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
