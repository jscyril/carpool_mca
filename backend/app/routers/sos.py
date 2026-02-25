"""
SOS Router — emergency SOS alerts (demo).

Endpoints:
- POST /sos/ — Trigger an SOS alert
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from uuid import UUID

from core.deps import DBSession, VerifiedUser
from db.models.sos_alerts import SOSAlert
from db.models.rides import Ride
from schemas.sos import SOSAlertCreate, SOSAlertRead

router = APIRouter(
    prefix="/sos",
    tags=["SOS"]
)


@router.post("/", response_model=SOSAlertRead, status_code=status.HTTP_201_CREATED)
async def trigger_sos(
    body: SOSAlertCreate,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Trigger an SOS alert during a ride.
    Stores in DB and prints to console (demo mode).
    """
    # Validate ride exists
    result = await db.execute(select(Ride).where(Ride.ride_id == body.ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ride not found")

    # Create SOS alert with location as WKT POINT
    location_wkt = f"SRID=4326;POINT({body.longitude} {body.latitude})"

    alert = SOSAlert(
        user_id=current_user.user_id,
        ride_id=body.ride_id,
        location=location_wkt
    )
    db.add(alert)
    await db.flush()
    await db.refresh(alert)

    # Console output (demo)
    print(f"[SOS ALERT] User {current_user.user_id} — Ride {body.ride_id} — Location: {body.latitude},{body.longitude}")

    return alert
