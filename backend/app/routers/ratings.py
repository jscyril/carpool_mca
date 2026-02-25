"""
Ratings Router — post-ride ratings and user rating summary.

Endpoints:
- POST /rides/{ride_id}/ratings — Submit a post-ride rating
- GET /users/{user_id}/ratings — Get user's average rating
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func
from uuid import UUID

from core.deps import DBSession, VerifiedUser
from db.models.rides import Ride
from db.models.ratings import Rating
from db.enums import RideStatusEnum
from schemas.ratings import RatingCreate, RatingRead, UserRatingSummary

router = APIRouter(tags=["Ratings"])


@router.post("/rides/{ride_id}/ratings", response_model=RatingRead, status_code=status.HTTP_201_CREATED)
async def submit_rating(
    ride_id: UUID,
    body: RatingCreate,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Submit a post-ride rating. Ride must be completed.
    Rater cannot rate themselves. One rating per rater+rated+ride combo.
    """
    # Validate ride exists and is completed
    result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ride not found")
    if ride.status != RideStatusEnum.completed:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Can only rate completed rides")

    # Can't rate yourself
    if str(current_user.user_id) == str(body.rated_user_id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot rate yourself")

    # Check for duplicate
    existing = await db.execute(
        select(Rating).where(
            Rating.ride_id == ride_id,
            Rating.rater_id == current_user.user_id,
            Rating.rated_user_id == body.rated_user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "You have already rated this user for this ride")

    rating = Rating(
        ride_id=ride_id,
        rater_id=current_user.user_id,
        rated_user_id=body.rated_user_id,
        rating_value=body.rating_value,
        comment=body.comment
    )
    db.add(rating)
    await db.flush()
    await db.refresh(rating)
    return rating


@router.get("/users/{user_id}/ratings", response_model=UserRatingSummary)
async def get_user_ratings(
    user_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """Get a user's average rating and total rating count."""
    result = await db.execute(
        select(
            func.avg(Rating.rating_value).label("avg_rating"),
            func.count(Rating.rating_id).label("total")
        ).where(Rating.rated_user_id == user_id)
    )
    row = result.one()
    avg_rating = float(row.avg_rating) if row.avg_rating else 0.0
    total = row.total or 0

    return UserRatingSummary(
        user_id=user_id,
        average_rating=round(avg_rating, 2),
        total_ratings=total
    )
