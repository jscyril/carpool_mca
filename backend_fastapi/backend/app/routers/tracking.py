"""
Tracking Router — Provides ride tracking info for live tracking UI.

GET  /tracking/{ride_id}           — Returns current ride state for the live tracking screen.
POST /tracking/{ride_id}/location  — Driver updates their live location (stored in-memory/cache).
GET  /tracking/{ride_id}/location  — Get driver's latest live location.
"""
import uuid
from typing import Optional
from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from core.deps import DBSession, CurrentUser
from db.models.rides import Ride


router = APIRouter(prefix="/tracking", tags=["Tracking"])

# ---------------------------------------------------------------------------
# In-memory driver location store (sufficient for demo + single-server setup)
# Replace with Redis for multi-instance production
# ---------------------------------------------------------------------------
_driver_locations: dict[str, dict] = {}


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float


def _geo_to_coords(geo_value) -> Optional[dict]:
    """Convert a GeoAlchemy2 Geography value to {latitude, longitude} dict."""
    if geo_value is None:
        return None
    try:
        from geoalchemy2.shape import to_shape
        point = to_shape(geo_value)
        return {"latitude": point.y, "longitude": point.x}
    except Exception:
        return None


@router.get("/{ride_id}")
async def get_tracking_info(
    ride_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """
    Get tracking information for a ride.

    Returns ride status, locations, driver/rider names, and OTP (for rider only).
    The frontend uses this to drive the live tracking screen.
    """
    result = await db.execute(
        select(Ride)
        .options(selectinload(Ride.driver), selectinload(Ride.vehicle))
        .where(Ride.ride_id == ride_id)
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

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

    # Get live driver location (from in-memory store, updated by driver app)
    live_location = _driver_locations.get(str(ride_id))

    return {
        "ride_id": str(ride.ride_id),
        "status": ride.status.value,
        "start_location": _geo_to_coords(ride.start_location),
        "end_location": _geo_to_coords(ride.end_location),
        "start_address": ride.start_address,
        "end_address": ride.end_address,
        "driver": driver_info,
        "vehicle": vehicle_info,
        # Passengers see their pickup OTP; driver does not see it here
        "pickup_otp": ride.pickup_otp if not is_driver else None,
        # Live driver location for map tracking
        "driver_location": live_location,
    }


@router.post("/{ride_id}/location", status_code=200)
async def update_driver_location(
    ride_id: uuid.UUID,
    payload: LocationUpdate,
    user: CurrentUser,
    db: DBSession,
):
    """
    Driver posts their current GPS location.
    Passengers polling GET /tracking/{ride_id} will receive it.
    """
    result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not your ride")

    _driver_locations[str(ride_id)] = {
        "latitude": payload.latitude,
        "longitude": payload.longitude,
    }
    return {"message": "Location updated"}


@router.delete("/{ride_id}/location", status_code=200)
async def clear_driver_location(
    ride_id: uuid.UUID,
    user: CurrentUser,
    db: DBSession,
):
    """Clear stored driver location when ride completes."""
    result = await db.execute(
        select(Ride).where(Ride.ride_id == ride_id, Ride.driver_id == user.user_id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not your ride")

    _driver_locations.pop(str(ride_id), None)
    return {"message": "Location cleared"}
