"""
Driver Profiles Router — Create, view, update driver profiles.
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.driver_profiles import DriverProfile
from db.models.vehicles import Vehicle
from schemas.driver_profiles import (
    DriverProfileCreate,
    DriverProfileRead,
    DriverProfileUpdate,
)


router = APIRouter(prefix="/driver-profiles", tags=["Driver Profiles"])


@router.post("/", response_model=DriverProfileRead, status_code=status.HTTP_201_CREATED)
async def create_driver_profile(
    payload: DriverProfileCreate, user: CurrentUser, db: DBSession
):
    """Create a driver profile for the current user."""
    # Check if profile already exists
    existing = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == user.user_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Driver profile already exists. Use PUT to update.",
        )

    # Verify vehicle belongs to user
    v_result = await db.execute(
        select(Vehicle).where(
            Vehicle.vehicle_id == payload.vehicle_id,
            Vehicle.user_id == user.user_id,
        )
    )
    vehicle = v_result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or does not belong to you.",
        )

    profile = DriverProfile(
        user_id=user.user_id,
        vehicle_id=payload.vehicle_id,
        daily_seat_limit=payload.daily_seat_limit,
    )
    db.add(profile)
    await db.flush()
    await db.refresh(profile)

    return DriverProfileRead(
        user_id=profile.user_id,
        vehicle_id=profile.vehicle_id,
        daily_seat_limit=profile.daily_seat_limit,
        is_driver_active=profile.is_driver_active,
        vehicle_number=vehicle.vehicle_number,
    )


@router.get("/me", response_model=DriverProfileRead)
async def get_my_driver_profile(user: CurrentUser, db: DBSession):
    """Get the current user's driver profile."""
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == user.user_id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No driver profile found. Create one first.",
        )

    # Get vehicle number
    v_result = await db.execute(
        select(Vehicle).where(Vehicle.vehicle_id == profile.vehicle_id)
    )
    vehicle = v_result.scalar_one_or_none()

    return DriverProfileRead(
        user_id=profile.user_id,
        vehicle_id=profile.vehicle_id,
        daily_seat_limit=profile.daily_seat_limit,
        is_driver_active=profile.is_driver_active,
        vehicle_number=vehicle.vehicle_number if vehicle else None,
    )


@router.put("/me", response_model=DriverProfileRead)
async def update_driver_profile(
    payload: DriverProfileUpdate, user: CurrentUser, db: DBSession
):
    """Update the current user's driver profile."""
    result = await db.execute(
        select(DriverProfile).where(DriverProfile.user_id == user.user_id)
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No driver profile found.",
        )

    if payload.vehicle_id is not None:
        # Verify new vehicle belongs to user
        v_check = await db.execute(
            select(Vehicle).where(
                Vehicle.vehicle_id == payload.vehicle_id,
                Vehicle.user_id == user.user_id,
            )
        )
        if not v_check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehicle not found or does not belong to you.",
            )
        profile.vehicle_id = payload.vehicle_id

    if payload.daily_seat_limit is not None:
        profile.daily_seat_limit = payload.daily_seat_limit
    if payload.is_driver_active is not None:
        profile.is_driver_active = payload.is_driver_active

    await db.flush()
    await db.refresh(profile)

    # Get vehicle number
    v_result = await db.execute(
        select(Vehicle).where(Vehicle.vehicle_id == profile.vehicle_id)
    )
    vehicle = v_result.scalar_one_or_none()

    return DriverProfileRead(
        user_id=profile.user_id,
        vehicle_id=profile.vehicle_id,
        daily_seat_limit=profile.daily_seat_limit,
        is_driver_active=profile.is_driver_active,
        vehicle_number=vehicle.vehicle_number if vehicle else None,
    )
