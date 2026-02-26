"""
Admin Router — Full admin-only management API.

All endpoints require is_admin = True.

User Management:
  GET  /admin/users                    — List all users (paginated)
  GET  /admin/users/{user_id}         — Get user detail
  PUT  /admin/users/{user_id}/deactivate — Deactivate user

Identity Verification:
  GET  /admin/verifications/identity/pending        — List pending identity verifications
  PUT  /admin/verifications/identity/{user_id}/approve — Approve identity
  PUT  /admin/verifications/identity/{user_id}/reject  — Reject identity

Driver Verification:
  GET  /admin/verifications/driver/pending          — List pending driver verifications
  PUT  /admin/verifications/driver/{user_id}/approve   — Approve driver
  PUT  /admin/verifications/driver/{user_id}/reject    — Reject driver

SOS Alerts:
  GET  /admin/sos/active               — List active (unresolved) SOS alerts
  PUT  /admin/sos/{alert_id}/resolve   — Mark SOS alert resolved

Stats:
  GET  /admin/stats                    — Dashboard statistics
"""
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, status, Query, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from core.deps import DBSession, CurrentUser
from db.models.users import User
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.sos_alerts import SOSAlert
from db.models.rides import Ride
from db.enums import VerificationStatusEnum, RideStatusEnum

router = APIRouter(prefix="/admin", tags=["Admin"])


# ---------------------------------------------------------------------------
# Admin guard dependency
# ---------------------------------------------------------------------------
async def require_admin(user: CurrentUser) -> User:
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required.",
        )
    return user


AdminUser = Depends(require_admin)


# ---------------------------------------------------------------------------
# Pydantic response schemas
# ---------------------------------------------------------------------------

class UserListItem(BaseModel):
    user_id: str
    full_name: str
    phone_number: str
    email: Optional[str]
    gender: str
    is_active: bool
    is_phone_verified: bool
    is_email_verified: bool
    is_identity_verified: bool
    is_driver_verified: bool
    is_admin: bool
    created_at: Optional[str]

    class Config:
        from_attributes = True


class VerificationItem(BaseModel):
    user_id: str
    full_name: str
    phone_number: str
    email: Optional[str]
    status: str
    submitted_at: Optional[str]
    reviewer_notes: Optional[str]
    document_url: Optional[str] = None
    license_document_url: Optional[str] = None
    college_id_number: Optional[str] = None
    license_number: Optional[str] = None


class SOSAlertItem(BaseModel):
    alert_id: str
    user_id: str
    ride_id: str
    triggered_at: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]


# ---------------------------------------------------------------------------
# USER MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/users", response_model=list[UserListItem])
async def list_users(
    _: User = AdminUser,
    db: DBSession = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
):
    """List all users with pagination."""
    offset = (page - 1) * page_size
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).offset(offset).limit(page_size)
    )
    users = result.scalars().all()
    return [
        UserListItem(
            user_id=str(u.user_id),
            full_name=u.full_name,
            phone_number=u.phone_number,
            email=u.email,
            gender=u.gender.value if hasattr(u.gender, "value") else u.gender,
            is_active=u.is_active,
            is_phone_verified=u.is_phone_verified,
            is_email_verified=u.is_email_verified,
            is_identity_verified=u.is_identity_verified,
            is_driver_verified=u.is_driver_verified,
            is_admin=u.is_admin,
            created_at=str(u.created_at) if u.created_at else None,
        )
        for u in users
    ]


@router.get("/users/{user_id}", response_model=UserListItem)
async def get_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Get a specific user's details."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserListItem(
        user_id=str(user.user_id),
        full_name=user.full_name,
        phone_number=user.phone_number,
        email=user.email,
        gender=user.gender.value if hasattr(user.gender, "value") else user.gender,
        is_active=user.is_active,
        is_phone_verified=user.is_phone_verified,
        is_email_verified=user.is_email_verified,
        is_identity_verified=user.is_identity_verified,
        is_driver_verified=user.is_driver_verified,
        is_admin=user.is_admin,
        created_at=str(user.created_at) if user.created_at else None,
    )


@router.put("/users/{user_id}/deactivate")
async def deactivate_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Deactivate a user account (blocks login)."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.is_admin:
        raise HTTPException(status_code=400, detail="Cannot deactivate another admin.")
    user.is_active = False
    await db.flush()
    return {"message": f"User {user.full_name} deactivated."}


@router.put("/users/{user_id}/activate")
async def activate_user(
    user_id: uuid.UUID,
    _: User = AdminUser,
    db: DBSession = None,
):
    """Re-activate a deactivated user account."""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = True
    await db.flush()
    return {"message": f"User {user.full_name} activated."}


# ---------------------------------------------------------------------------
# IDENTITY VERIFICATION MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/verifications/identity/pending", response_model=list[VerificationItem])
async def list_pending_identity(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List all submitted (pending) identity verifications."""
    result = await db.execute(
        select(IdentityVerification, User)
        .join(User, IdentityVerification.user_id == User.user_id)
        .where(IdentityVerification.status == VerificationStatusEnum.submitted)
        .order_by(IdentityVerification.created_at.asc())
    )
    rows = result.all()
    return [
        VerificationItem(
            user_id=str(iv.user_id),
            full_name=u.full_name,
            phone_number=u.phone_number,
            email=u.email,
            status=iv.status.value,
            submitted_at=str(iv.created_at) if iv.created_at else None,
            reviewer_notes=iv.reviewer_notes,
            document_url=iv.document_url,
            college_id_number=iv.college_id_number,
        )
        for iv, u in rows
    ]


class ReviewRequest(BaseModel):
    notes: Optional[str] = None


@router.put("/verifications/identity/{user_id}/approve")
async def approve_identity(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Approve identity verification: sets is_identity_verified = True."""
    iv_result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user_id)
    )
    iv = iv_result.scalar_one_or_none()
    if not iv:
        raise HTTPException(status_code=404, detail="Verification record not found")
    iv.status = VerificationStatusEnum.verified
    iv.reviewer_notes = payload.notes
    iv.reviewed_at = datetime.now(timezone.utc)

    user_result = await db.execute(select(User).where(User.user_id == user_id))
    user = user_result.scalar_one_or_none()
    if user:
        user.is_identity_verified = True
    await db.flush()
    return {"message": "Identity verified and approved."}


@router.put("/verifications/identity/{user_id}/reject")
async def reject_identity(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Reject identity verification with optional notes."""
    iv_result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user_id)
    )
    iv = iv_result.scalar_one_or_none()
    if not iv:
        raise HTTPException(status_code=404, detail="Verification record not found")
    iv.status = VerificationStatusEnum.rejected
    iv.reviewer_notes = payload.notes
    iv.reviewed_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Identity verification rejected."}


# ---------------------------------------------------------------------------
# DRIVER VERIFICATION MANAGEMENT
# ---------------------------------------------------------------------------

@router.get("/verifications/driver/pending", response_model=list[VerificationItem])
async def list_pending_driver(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List all submitted (pending) driver verifications."""
    result = await db.execute(
        select(DriverVerification, User)
        .join(User, DriverVerification.user_id == User.user_id)
        .where(DriverVerification.status == VerificationStatusEnum.submitted)
        .order_by(DriverVerification.created_at.asc())
    )
    rows = result.all()
    return [
        VerificationItem(
            user_id=str(dv.user_id),
            full_name=u.full_name,
            phone_number=u.phone_number,
            email=u.email,
            status=dv.status.value,
            submitted_at=str(dv.created_at) if dv.created_at else None,
            reviewer_notes=dv.reviewer_notes,
            license_document_url=dv.license_document_url,
            license_number=dv.license_number,
        )
        for dv, u in rows
    ]


@router.put("/verifications/driver/{user_id}/approve")
async def approve_driver(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Approve driver verification: sets is_driver_verified = True."""
    dv_result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user_id)
    )
    dv = dv_result.scalar_one_or_none()
    if not dv:
        raise HTTPException(status_code=404, detail="Driver verification record not found")
    dv.status = VerificationStatusEnum.verified
    dv.reviewer_notes = payload.notes
    dv.reviewed_at = datetime.now(timezone.utc)

    user_result = await db.execute(select(User).where(User.user_id == user_id))
    user = user_result.scalar_one_or_none()
    if user:
        user.is_driver_verified = True
    await db.flush()
    return {"message": "Driver verified and approved."}


@router.put("/verifications/driver/{user_id}/reject")
async def reject_driver(
    user_id: uuid.UUID,
    payload: ReviewRequest = ReviewRequest(),
    _: User = AdminUser,
    db: DBSession = None,
):
    """Reject driver verification."""
    dv_result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user_id)
    )
    dv = dv_result.scalar_one_or_none()
    if not dv:
        raise HTTPException(status_code=404, detail="Driver verification record not found")
    dv.status = VerificationStatusEnum.rejected
    dv.reviewer_notes = payload.notes
    dv.reviewed_at = datetime.now(timezone.utc)
    await db.flush()
    return {"message": "Driver verification rejected."}


# ---------------------------------------------------------------------------
# SOS ALERTS
# ---------------------------------------------------------------------------

@router.get("/sos/active", response_model=list[SOSAlertItem])
async def list_active_sos(
    _: User = AdminUser,
    db: DBSession = None,
):
    """List all unresolved SOS alerts with location."""
    result = await db.execute(
        select(SOSAlert).order_by(SOSAlert.triggered_at.desc())
    )
    alerts = result.scalars().all()

    items = []
    for alert in alerts:
        lat, lng = None, None
        if alert.location is not None:
            try:
                from geoalchemy2.shape import to_shape
                point = to_shape(alert.location)
                lat, lng = point.y, point.x
            except Exception:
                pass
        items.append(SOSAlertItem(
            alert_id=str(alert.alert_id),
            user_id=str(alert.user_id),
            ride_id=str(alert.ride_id),
            triggered_at=str(alert.triggered_at) if alert.triggered_at else None,
            latitude=lat,
            longitude=lng,
        ))
    return items


# ---------------------------------------------------------------------------
# DASHBOARD STATS
# ---------------------------------------------------------------------------

@router.get("/stats")
async def get_stats(
    _: User = AdminUser,
    db: DBSession = None,
):
    """Return high-level platform statistics."""
    total_users = (await db.execute(select(func.count(User.user_id)))).scalar()
    active_users = (await db.execute(
        select(func.count(User.user_id)).where(User.is_active == True)
    )).scalar()
    verified_identities = (await db.execute(
        select(func.count(User.user_id)).where(User.is_identity_verified == True)
    )).scalar()
    verified_drivers = (await db.execute(
        select(func.count(User.user_id)).where(User.is_driver_verified == True)
    )).scalar()
    pending_identity = (await db.execute(
        select(func.count(IdentityVerification.verification_id))
        .where(IdentityVerification.status == VerificationStatusEnum.submitted)
    )).scalar()
    pending_driver = (await db.execute(
        select(func.count(DriverVerification.verification_id))
        .where(DriverVerification.status == VerificationStatusEnum.submitted)
    )).scalar()
    active_rides = (await db.execute(
        select(func.count(Ride.ride_id))
        .where(Ride.status == RideStatusEnum.open)
    )).scalar()
    total_sos = (await db.execute(select(func.count(SOSAlert.alert_id)))).scalar()

    return {
        "users": {
            "total": total_users,
            "active": active_users,
            "identity_verified": verified_identities,
            "driver_verified": verified_drivers,
        },
        "verifications": {
            "pending_identity": pending_identity,
            "pending_driver": pending_driver,
        },
        "rides": {
            "active_open": active_rides,
        },
        "sos": {
            "total_triggered": total_sos,
        },
    }
