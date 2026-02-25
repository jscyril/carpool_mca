"""
Fare Router — fare estimation and splitting.

Endpoints:
- GET /rides/{ride_id}/fare — Calculate fare based on PostGIS distance
- GET /rides/{ride_id}/fare/split — Split fare among confirmed participants
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func
from uuid import UUID

from core.deps import DBSession, VerifiedUser
from db.models.rides import Ride
from db.models.fare_estimates import FareEstimate
from db.models.ride_participants import RideParticipant
from schemas.fare import FareEstimateRead, FareSplitRead

router = APIRouter(
    prefix="/rides",
    tags=["Fare"]
)

# Rate per km (configurable later)
FARE_PER_KM = 10.0


@router.get("/{ride_id}/fare", response_model=FareEstimateRead)
async def get_fare_estimate(
    ride_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Calculate fare estimate for a ride based on PostGIS distance.
    Creates/updates the FareEstimate record.
    """
    # Get ride
    result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ride not found")

    # Calculate distance using PostGIS
    dist_result = await db.execute(
        select(func.ST_Distance(ride.start_location, ride.end_location).label("distance"))
    )
    distance_m = dist_result.scalar()
    distance_km = round(distance_m / 1000, 2) if distance_m else 0.0
    estimated_fare = round(distance_km * FARE_PER_KM, 2)

    # Upsert fare estimate
    existing = await db.execute(
        select(FareEstimate).where(FareEstimate.ride_id == ride_id)
    )
    fare = existing.scalar_one_or_none()

    if fare:
        fare.distance_km = distance_km
        fare.estimated_fare = estimated_fare
    else:
        fare = FareEstimate(
            ride_id=ride_id,
            distance_km=distance_km,
            estimated_fare=estimated_fare
        )
        db.add(fare)

    await db.flush()
    await db.refresh(fare)
    return fare


@router.get("/{ride_id}/fare/split", response_model=FareSplitRead)
async def get_fare_split(
    ride_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Split fare among confirmed participants + driver.
    """
    # Get fare estimate (or calculate it)
    result = await db.execute(
        select(FareEstimate).where(FareEstimate.ride_id == ride_id)
    )
    fare = result.scalar_one_or_none()

    if not fare:
        # Calculate on the fly
        ride_result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
        ride = ride_result.scalar_one_or_none()
        if not ride:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ride not found")

        dist_result = await db.execute(
            select(func.ST_Distance(ride.start_location, ride.end_location).label("distance"))
        )
        distance_m = dist_result.scalar()
        distance_km = round(distance_m / 1000, 2) if distance_m else 0.0
        estimated_fare = round(distance_km * FARE_PER_KM, 2)

        fare = FareEstimate(
            ride_id=ride_id,
            distance_km=distance_km,
            estimated_fare=estimated_fare
        )
        db.add(fare)
        await db.flush()
        await db.refresh(fare)

    # Count participants
    participant_result = await db.execute(
        select(func.count(RideParticipant.participant_id))
        .where(RideParticipant.ride_id == ride_id)
    )
    participant_count = participant_result.scalar() or 0

    # Split among participants + driver
    total_people = participant_count + 1  # include driver
    per_person = round(float(fare.estimated_fare) / total_people, 2)

    return FareSplitRead(
        total_fare=float(fare.estimated_fare),
        distance_km=float(fare.distance_km),
        participant_count=participant_count,
        per_person=per_person
    )
