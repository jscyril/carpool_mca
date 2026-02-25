"""
Tracking Router — Provides ride tracking info for live tracking UI.

GET /tracking/{ride_id} — Returns current ride state for the live tracking screen.
"""
import uuid
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from core.deps import DBSession, CurrentUser
from db.models.rides import Ride
from db.models.users import User
from schemas.common import LocationPoint


router = APIRouter(prefix="/tracking", tags=["Tracking"])


@router.get("/{ride_id}")
async def get_tracking_info(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """
    Get tracking information for a ride.

    Returns ride status, locations, driver/rider names, and OTP (for rider only).
    The frontend uses this to drive the simulation.
    """
    result = await db.execute(
        select(Ride)
        .options(selectinload(Ride.driver), selectinload(Ride.vehicle))
        .where(Ride.ride_id == ride_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    # Check the user is involved in this ride
    is_driver = ride.driver_id == user.user_id

    driver_info = None
    if ride.driver:
        driver_info = {
            "user_id": str(ride.driver.user_id),
            "full_name": ride.driver.full_name,
            "phone_number": ride.driver.phone_number,
        }

    vehicle_info = None
    if ride.vehicle:
        vehicle_info = {
            "vehicle_number": ride.vehicle.vehicle_number,
            "vehicle_type": ride.vehicle.vehicle_type.value,
        }

    return {
        "ride_id": str(ride.ride_id),
        "status": ride.status.value,
        "start_location": {
            "latitude": ride.start_location,
            "longitude": ride.start_location,
        } if ride.start_location else None,
        "end_location": {
            "latitude": ride.end_location,
            "longitude": ride.end_location,
        } if ride.end_location else None,
        "start_address": ride.start_address,
        "end_address": ride.end_address,
        "driver": driver_info,
        "vehicle": vehicle_info,
        "pickup_otp": ride.pickup_otp if not is_driver else None,
    }
