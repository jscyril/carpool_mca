"""
Driver Profiles Router — Create, view, and update driver profile.

All endpoints require driver verification.
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, VerifiedDriver
from db.models.driver_profiles import DriverProfile
from db.models.vehicles import Vehicle
from schemas.driver_profiles import (
    DriverProfileCreate, DriverProfileRead, DriverProfileUpdate
)

router = APIRouter(
    prefix="/driver-profiles",
    tags=["Driver Profiles"]
)


async def _build_profile_read(db, profile: DriverProfile) -> DriverProfileRead:
    """Build DriverProfileRead with joined vehicle number."""
    result = await db.execute(
        select(Vehicle).where(Vehicle.vehicle_id == profile.vehicle_id)
    )
    vehicle = result.scalar_one_or_none()
    return DriverProfileRead(
        user_id=profile.user_id,
        vehicle_id=profile.vehicle_id,
        daily_seat_limit=profile.daily_seat_limit,
        is_driver_active=profile.is_driver_active,
        vehicle_number=vehicle.vehicle_number if vehicle else None
    )


@router.post("/", response_model=DriverProfileRead, status_code=status.HTTP_201_CREATED)
async def create_or_update_profile(
    body: DriverProfileCreate,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Create or upsert driver profile.
    If profile exists, updates it (upsert behavior).
    Vehicle must belong to the user.
    """
    # Validate vehicle ownership
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.vehicle_id == body.vehicle_id,
            Vehicle.user_id == current_user.user_id
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Vehicle not found or does not belong to you")

    # Check if profile exists (upsert)
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == current_user.user_id)
    )
    profile = result.scalar_one_or_none()

    if profile:
        # Update existing
        profile.vehicle_id = body.vehicle_id
        profile.daily_seat_limit = body.daily_seat_limit
    else:
        # Create new
        profile = DriverProfile(
            user_id=current_user.user_id,
            vehicle_id=body.vehicle_id,
            daily_seat_limit=body.daily_seat_limit,
            is_driver_active=True
        )
        db.add(profile)

    await db.flush()
    return await _build_profile_read(db, profile)


@router.get("/me", response_model=DriverProfileRead)
async def get_my_profile(
    current_user: VerifiedDriver,
    db: DBSession
):
    """Get own driver profile."""
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == current_user.user_id)
    )
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Driver profile not found. Create one first.")

    return await _build_profile_read(db, profile)


@router.put("/me", response_model=DriverProfileRead)
async def update_my_profile(
    body: DriverProfileUpdate,
    current_user: VerifiedDriver,
    db: DBSession
):
    """Partial update of driver profile."""
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == current_user.user_id)
    )
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Driver profile not found. Create one first.")

    update_data = body.model_dump(exclude_unset=True)

    # Validate vehicle if changing
    if "vehicle_id" in update_data:
        result = await db.execute(
            select(Vehicle).where(
                Vehicle.vehicle_id == update_data["vehicle_id"],
                Vehicle.user_id == current_user.user_id
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Vehicle not found or does not belong to you")

    for field, value in update_data.items():
        setattr(profile, field, value)

    await db.flush()
    return await _build_profile_read(db, profile)
