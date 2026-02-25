"""
Admin Router — platform management for admin users.

Endpoints:
- GET /admin/users — List/search users with filters
- PUT /admin/users/{user_id}/deactivate — Deactivate a user
- GET /admin/verifications/identity — Pending identity verifications
- PUT /admin/verifications/identity/{verification_id} — Approve/reject identity
- GET /admin/verifications/driver — Pending driver verifications
- PUT /admin/verifications/driver/{verification_id} — Approve/reject driver
- GET /admin/reports — View all reports
- PUT /admin/reports/{report_id} — Acknowledge report
- GET /admin/stats — Platform statistics
"""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy import select, func, or_
from uuid import UUID

from core.deps import DBSession, AdminUser
from db.models.users import User
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.reports import Report
from db.models.rides import Ride
from db.enums import VerificationStatusEnum, RideStatusEnum

router = APIRouter(
    prefix="/admin",
    tags=["Admin"]
)


# =============================================================================
# SCHEMAS
# =============================================================================

class AdminUserRead(BaseModel):
    user_id: UUID
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone_number: str
    is_active: bool
    is_identity_verified: bool
    is_driver_verified: bool
    is_admin: bool

    class Config:
        from_attributes = True


class VerificationAction(BaseModel):
    action: str = Field(..., pattern="^(approve|reject)$")
    admin_notes: Optional[str] = None


class ReportAction(BaseModel):
    action: str = Field(..., pattern="^(reviewed|dismissed)$")


class PlatformStats(BaseModel):
    total_users: int
    active_users: int
    verified_users: int
    verified_drivers: int
    total_rides: int
    rides_open: int
    rides_ongoing: int
    rides_completed: int
    rides_cancelled: int
    total_reports: int


# =============================================================================
# USER MANAGEMENT
# =============================================================================

@router.get("/users", response_model=List[AdminUserRead])
async def list_users(
    admin: AdminUser,
    db: DBSession,
    search: Optional[str] = Query(None, description="Search by name, email, or phone"),
    is_active: Optional[bool] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """List/search users with filters."""
    stmt = select(User)

    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            or_(
                User.full_name.ilike(pattern),
                User.email.ilike(pattern),
                User.phone_number.ilike(pattern),
            )
        )

    if is_active is not None:
        stmt = stmt.where(User.is_active == is_active)

    stmt = stmt.offset(skip).limit(limit).order_by(User.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.put("/users/{user_id}/deactivate", response_model=AdminUserRead)
async def deactivate_user(
    user_id: UUID,
    admin: AdminUser,
    db: DBSession,
):
    """Deactivate a user account."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

    user.is_active = False
    await db.flush()
    await db.refresh(user)
    return user


# =============================================================================
# IDENTITY VERIFICATION APPROVALS
# =============================================================================

@router.get("/verifications/identity")
async def list_identity_verifications(
    admin: AdminUser,
    db: DBSession,
    verification_status: Optional[str] = Query("submitted", alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """List identity verifications, default: submitted (pending review)."""
    stmt = select(IdentityVerification)

    if verification_status:
        try:
            status_enum = VerificationStatusEnum(verification_status)
            stmt = stmt.where(IdentityVerification.status == status_enum)
        except ValueError:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"Invalid status. Must be one of: {[s.value for s in VerificationStatusEnum]}"
            )

    stmt = stmt.offset(skip).limit(limit).order_by(IdentityVerification.submitted_at.desc())
    result = await db.execute(stmt)
    verifications = result.scalars().all()

    # Build response with user info
    response = []
    for v in verifications:
        user_result = await db.execute(select(User).where(User.user_id == v.user_id))
        user = user_result.scalar_one_or_none()
        response.append({
            "id": str(v.id),
            "user_id": str(v.user_id),
            "user_name": user.full_name if user else None,
            "college_id_image_url": v.college_id_image_url,
            "extracted_name": v.extracted_name,
            "extracted_register_number": v.extracted_register_number,
            "status": v.status.value,
            "admin_notes": v.admin_notes,
            "submitted_at": str(v.submitted_at),
            "reviewed_at": str(v.reviewed_at) if v.reviewed_at else None,
        })
    return response


@router.put("/verifications/identity/{verification_id}")
async def action_identity_verification(
    verification_id: UUID,
    body: VerificationAction,
    admin: AdminUser,
    db: DBSession,
):
    """Approve or reject an identity verification."""
    result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.id == verification_id)
    )
    verification = result.scalar_one_or_none()
    if not verification:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Verification not found")

    now = datetime.now(timezone.utc)

    if body.action == "approve":
        verification.status = VerificationStatusEnum.verified
        verification.reviewed_at = now
        verification.admin_notes = body.admin_notes

        # Auto-flag user
        user_result = await db.execute(select(User).where(User.user_id == verification.user_id))
        user = user_result.scalar_one_or_none()
        if user:
            user.is_identity_verified = True
    else:
        verification.status = VerificationStatusEnum.rejected
        verification.reviewed_at = now
        verification.admin_notes = body.admin_notes

    await db.flush()
    await db.refresh(verification)
    return {
        "id": str(verification.id),
        "status": verification.status.value,
        "admin_notes": verification.admin_notes,
        "reviewed_at": str(verification.reviewed_at),
    }


# =============================================================================
# DRIVER VERIFICATION APPROVALS
# =============================================================================

@router.get("/verifications/driver")
async def list_driver_verifications(
    admin: AdminUser,
    db: DBSession,
    verification_status: Optional[str] = Query("submitted", alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """List driver verifications, default: submitted (pending review)."""
    stmt = select(DriverVerification)

    if verification_status:
        try:
            status_enum = VerificationStatusEnum(verification_status)
            stmt = stmt.where(DriverVerification.status == status_enum)
        except ValueError:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"Invalid status. Must be one of: {[s.value for s in VerificationStatusEnum]}"
            )

    stmt = stmt.offset(skip).limit(limit).order_by(DriverVerification.submitted_at.desc())
    result = await db.execute(stmt)
    verifications = result.scalars().all()

    response = []
    for v in verifications:
        user_result = await db.execute(select(User).where(User.user_id == v.user_id))
        user = user_result.scalar_one_or_none()
        response.append({
            "id": str(v.id),
            "user_id": str(v.user_id),
            "user_name": user.full_name if user else None,
            "license_number": v.license_number,
            "vehicle_registration_number": v.vehicle_registration_number,
            "status": v.status.value,
            "admin_notes": v.admin_notes,
            "submitted_at": str(v.submitted_at),
            "reviewed_at": str(v.reviewed_at) if v.reviewed_at else None,
        })
    return response


@router.put("/verifications/driver/{verification_id}")
async def action_driver_verification(
    verification_id: UUID,
    body: VerificationAction,
    admin: AdminUser,
    db: DBSession,
):
    """Approve or reject a driver verification."""
    result = await db.execute(
        select(DriverVerification).where(DriverVerification.id == verification_id)
    )
    verification = result.scalar_one_or_none()
    if not verification:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Verification not found")

    now = datetime.now(timezone.utc)

    if body.action == "approve":
        verification.status = VerificationStatusEnum.verified
        verification.reviewed_at = now
        verification.admin_notes = body.admin_notes

        # Auto-flag user
        user_result = await db.execute(select(User).where(User.user_id == verification.user_id))
        user = user_result.scalar_one_or_none()
        if user:
            user.is_driver_verified = True
    else:
        verification.status = VerificationStatusEnum.rejected
        verification.reviewed_at = now
        verification.admin_notes = body.admin_notes

    await db.flush()
    await db.refresh(verification)
    return {
        "id": str(verification.id),
        "status": verification.status.value,
        "admin_notes": verification.admin_notes,
        "reviewed_at": str(verification.reviewed_at),
    }


# =============================================================================
# REPORT MANAGEMENT
# =============================================================================

@router.get("/reports")
async def list_reports(
    admin: AdminUser,
    db: DBSession,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """List all user reports with reporter/reported names."""
    result = await db.execute(
        select(Report).offset(skip).limit(limit).order_by(Report.created_at.desc())
    )
    reports = result.scalars().all()

    response = []
    for r in reports:
        # Get reporter name
        reporter = await db.execute(select(User.full_name).where(User.user_id == r.reporter_id))
        reporter_name = reporter.scalar()
        # Get reported user name
        reported = await db.execute(select(User.full_name).where(User.user_id == r.reported_user_id))
        reported_name = reported.scalar()

        response.append({
            "report_id": str(r.report_id),
            "ride_id": str(r.ride_id),
            "reporter_id": str(r.reporter_id),
            "reporter_name": reporter_name,
            "reported_user_id": str(r.reported_user_id),
            "reported_name": reported_name,
            "comment": r.comment,
            "created_at": str(r.created_at),
        })
    return response


@router.put("/reports/{report_id}")
async def action_report(
    report_id: UUID,
    body: ReportAction,
    admin: AdminUser,
    db: DBSession,
):
    """Acknowledge a report (reviewed or dismissed)."""
    result = await db.execute(select(Report).where(Report.report_id == report_id))
    report = result.scalar_one_or_none()
    if not report:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Report not found")

    # Report model has no status field — return acknowledgment
    return {
        "report_id": str(report.report_id),
        "action": body.action,
        "message": f"Report {body.action}",
    }


# =============================================================================
# PLATFORM STATISTICS
# =============================================================================

@router.get("/stats", response_model=PlatformStats)
async def get_platform_stats(
    admin: AdminUser,
    db: DBSession,
):
    """Get platform-wide statistics."""
    # Users
    total_users = (await db.execute(select(func.count(User.user_id)))).scalar() or 0
    active_users = (await db.execute(
        select(func.count(User.user_id)).where(User.is_active == True)
    )).scalar() or 0
    verified_users = (await db.execute(
        select(func.count(User.user_id)).where(User.is_identity_verified == True)
    )).scalar() or 0
    verified_drivers = (await db.execute(
        select(func.count(User.user_id)).where(User.is_driver_verified == True)
    )).scalar() or 0

    # Rides
    total_rides = (await db.execute(select(func.count(Ride.ride_id)))).scalar() or 0
    rides_open = (await db.execute(
        select(func.count(Ride.ride_id)).where(Ride.status == RideStatusEnum.open)
    )).scalar() or 0
    rides_ongoing = (await db.execute(
        select(func.count(Ride.ride_id)).where(Ride.status == RideStatusEnum.ongoing)
    )).scalar() or 0
    rides_completed = (await db.execute(
        select(func.count(Ride.ride_id)).where(Ride.status == RideStatusEnum.completed)
    )).scalar() or 0
    rides_cancelled = (await db.execute(
        select(func.count(Ride.ride_id)).where(Ride.status == RideStatusEnum.cancelled)
    )).scalar() or 0

    # Reports
    total_reports = (await db.execute(select(func.count(Report.report_id)))).scalar() or 0

    return PlatformStats(
        total_users=total_users,
        active_users=active_users,
        verified_users=verified_users,
        verified_drivers=verified_drivers,
        total_rides=total_rides,
        rides_open=rides_open,
        rides_ongoing=rides_ongoing,
        rides_completed=rides_completed,
        rides_cancelled=rides_cancelled,
        total_reports=total_reports,
    )
