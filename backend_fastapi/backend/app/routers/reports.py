"""
Reports Router — Submit and view user reports.

Endpoints:
  POST /reports      — Submit a report against another user
  GET  /reports/mine — List reports submitted by current user
"""
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.reports import Report
from db.models.rides import Ride
from schemas.reports import ReportCreate, ReportRead


router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("/", response_model=ReportRead, status_code=status.HTTP_201_CREATED)
async def submit_report(
    payload: ReportCreate,
    user: CurrentUser,
    db: DBSession,
):
    """Submit a report against another user for a ride."""
    # Verify ride exists
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == payload.ride_id)
    )
    if not ride_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Ride not found")

    # Prevent self-reporting
    if payload.reported_user_id == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    # Check for duplicate report
    existing = await db.execute(
        select(Report).where(
            Report.ride_id == payload.ride_id,
            Report.reporter_id == user.user_id,
            Report.reported_user_id == payload.reported_user_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=409,
            detail="You already reported this user for this ride",
        )

    report = Report(
        report_id=uuid.uuid4(),
        ride_id=payload.ride_id,
        reporter_id=user.user_id,
        reported_user_id=payload.reported_user_id,
        comment=payload.comment,
    )
    db.add(report)
    await db.flush()
    await db.refresh(report)
    return report


@router.get("/mine", response_model=list[ReportRead])
async def get_my_reports(user: CurrentUser, db: DBSession):
    """List all reports submitted by the current user."""
    result = await db.execute(
        select(Report)
        .where(Report.reporter_id == user.user_id)
        .order_by(Report.created_at.desc())
    )
    return result.scalars().all()
