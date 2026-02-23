"""
SOS Router — Trigger and query SOS alerts during rides.

Endpoints:
  POST /sos/trigger  — Create an SOS alert (logs location, linked to ride)
  GET  /sos/active   — Get active SOS alerts for current user
"""
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from geoalchemy2.functions import ST_MakePoint

from core.deps import DBSession, CurrentUser
from db.models.sos_alerts import SOSAlert
from db.models.rides import Ride
from schemas.sos_alerts import SOSAlertCreate, SOSAlertRead


router = APIRouter(prefix="/sos", tags=["SOS"])


@router.post("/trigger", response_model=SOSAlertRead, status_code=status.HTTP_201_CREATED)
async def trigger_sos(
    payload: SOSAlertCreate,
    user: CurrentUser,
    db: DBSession,
):
    """
    Trigger an SOS alert during a ride.
    Stores the user's current location and links it to the ride.
    """
    # Verify ride exists
    ride_result = await db.execute(
        select(Ride).where(Ride.ride_id == payload.ride_id)
    )
    ride = ride_result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    alert = SOSAlert(
        alert_id=uuid.uuid4(),
        user_id=user.user_id,
        ride_id=payload.ride_id,
        location=ST_MakePoint(
            payload.location.longitude,
            payload.location.latitude,
            type_="GEOGRAPHY",
        ),
    )
    db.add(alert)
    await db.flush()
    await db.refresh(alert)
    return alert


@router.get("/active", response_model=list[SOSAlertRead])
async def get_active_alerts(user: CurrentUser, db: DBSession):
    """Get all SOS alerts triggered by the current user."""
    result = await db.execute(
        select(SOSAlert)
        .where(SOSAlert.user_id == user.user_id)
        .order_by(SOSAlert.triggered_at.desc())
    )
    return result.scalars().all()
