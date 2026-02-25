"""
Reports Router — user reporting.

Endpoints:
- POST /reports/ — Submit a user report
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from uuid import UUID

from core.deps import DBSession, VerifiedUser
from db.models.reports import Report
from schemas.reports import ReportCreate, ReportRead

router = APIRouter(
    prefix="/reports",
    tags=["Reports"]
)


@router.post("/", response_model=ReportRead, status_code=status.HTTP_201_CREATED)
async def submit_report(
    body: ReportCreate,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Submit a report against another user for a ride.
    Cannot report yourself. One report per ride+reporter+reported.
    """
    # Can't report yourself
    if str(current_user.user_id) == str(body.reported_user_id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot report yourself")

    # Check duplicate (unique constraint: ride + reporter + reported)
    existing = await db.execute(
        select(Report).where(
            Report.ride_id == body.ride_id,
            Report.reporter_id == current_user.user_id,
            Report.reported_user_id == body.reported_user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "You have already reported this user for this ride")

    report = Report(
        ride_id=body.ride_id,
        reporter_id=current_user.user_id,
        reported_user_id=body.reported_user_id,
        comment=body.comment
    )
    db.add(report)
    await db.flush()
    await db.refresh(report)
    return report
