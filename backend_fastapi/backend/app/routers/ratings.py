"""
Ratings Router — Post-ride ratings and user rating summaries.

Endpoints:
  POST /ratings/{ride_id}          — Submit a rating for a ride
  GET  /ratings/ride/{ride_id}     — Get all ratings for a ride
  GET  /ratings/user/{user_id}     — Get rating summary for a user
"""
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func

from core.deps import DBSession, CurrentUser
from db.models.ratings import Rating
from db.models.rides import Ride
from db.models.ride_participants import RideParticipant
from schemas.ratings import RatingCreate, RatingRead, UserRatingSummary


router = APIRouter(prefix="/ratings", tags=["Ratings"])


@router.post("/{ride_id}", response_model=RatingRead, status_code=status.HTTP_201_CREATED)
async def submit_rating(
    ride_id: uuid.UUID,
    payload: RatingCreate,
    user: CurrentUser,
    db: DBSession,
):
    """Submit a rating after a ride completes."""
    # Verify ride exists
    ride_result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
    ride = ride_result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")

    # Prevent self-rating
    if payload.rated_user_id == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot rate yourself")

    # Check that user was part of the ride (driver or participant)
    is_driver = ride.driver_id == user.user_id
    if not is_driver:
        p_result = await db.execute(
            select(RideParticipant).where(
                RideParticipant.ride_id == ride_id,
                RideParticipant.user_id == user.user_id,
            )
        )
        if not p_result.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="You were not part of this ride")

    # Check for duplicate rating
    existing = await db.execute(
        select(Rating).where(
            Rating.ride_id == ride_id,
            Rating.rater_id == user.user_id,
            Rating.rated_user_id == payload.rated_user_id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="You already rated this user for this ride")

    rating = Rating(
        rating_id=uuid.uuid4(),
        ride_id=ride_id,
        rater_id=user.user_id,
        rated_user_id=payload.rated_user_id,
        rating_value=payload.rating_value,
        comment=payload.comment,
    )
    db.add(rating)
    await db.flush()
    await db.refresh(rating)
    return rating


@router.get("/ride/{ride_id}", response_model=list[RatingRead])
async def get_ride_ratings(ride_id: uuid.UUID, db: DBSession):
    """Get all ratings for a specific ride."""
    result = await db.execute(
        select(Rating).where(Rating.ride_id == ride_id)
    )
    return result.scalars().all()


@router.get("/user/{user_id}", response_model=UserRatingSummary)
async def get_user_rating_summary(user_id: uuid.UUID, db: DBSession):
    """Get aggregated rating summary for a user."""
    result = await db.execute(
        select(
            func.avg(Rating.rating_value).label("average_rating"),
            func.count(Rating.rating_id).label("total_ratings"),
        ).where(Rating.rated_user_id == user_id)
    )
    row = result.one()

    return UserRatingSummary(
        user_id=user_id,
        average_rating=round(float(row.average_rating or 0), 1),
        total_ratings=int(row.total_ratings),
    )
