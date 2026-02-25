"""
Rides Router — Full ride lifecycle + geospatial search.

Endpoints:
- POST   /rides/               — Create ride (VerifiedDriver)
- GET    /rides/               — List rides (VerifiedUser)
- GET    /rides/search         — Geospatial proximity search (VerifiedUser)
- GET    /rides/distance       — Point-to-point distance calc (VerifiedUser)
- GET    /rides/my-rides       — User's ride history (CurrentUser)
- GET    /rides/{id}           — Ride details (VerifiedUser)
- POST   /rides/{id}/requests  — Request to join (VerifiedUser)
- GET    /rides/{id}/requests  — View requests (VerifiedDriver, ride owner)
- PUT    /rides/{id}/requests/{req_id} — Accept/reject (VerifiedDriver, ride owner)
- GET    /rides/{id}/participants — List confirmed riders (VerifiedUser)
- POST   /rides/{id}/start     — Start ride (VerifiedDriver, ride owner)
- POST   /rides/{id}/complete  — Complete ride (VerifiedDriver, ride owner)
- POST   /rides/{id}/cancel    — Cancel ride (VerifiedDriver, ride owner)
"""
from fastapi import APIRouter, HTTPException, status, Query
from sqlalchemy import select, or_, func
from sqlalchemy.orm import selectinload
from typing import List, Optional
from uuid import UUID
from datetime import date, datetime, timezone

from core.deps import DBSession, CurrentUser, VerifiedUser, VerifiedDriver
from db.models.rides import Ride
from db.models.ride_requests import RideRequest
from db.models.ride_participants import RideParticipant
from db.models.ride_history import RideHistory
from db.models.vehicles import Vehicle
from db.models.users import User
from schemas.rides import RideCreate, RideRead, RideParticipantRead, RideSearchResult
from schemas.ride_requests import (
    RideRequestRead, RideRequestAction, RideRequestWithUser
)
from db.enums import RideStatusEnum, RideRequestStatusEnum
from services.notification_service import notification_service

router = APIRouter(
    prefix="/rides",
    tags=["Rides"]
)


# =============================================================================
# HELPERS
# =============================================================================

async def _get_ride_or_404(db, ride_id: UUID) -> Ride:
    """Fetch a ride by ID or raise 404."""
    result = await db.execute(select(Ride).where(Ride.ride_id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ride not found")
    return ride


async def _get_owned_ride(db, ride_id: UUID, user_id) -> Ride:
    """Fetch a ride owned by the current user, or raise 403."""
    ride = await _get_ride_or_404(db, ride_id)
    if str(ride.driver_id) != str(user_id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You are not the driver of this ride")
    return ride


async def _get_participant_tokens(db, ride_id: UUID) -> list:
    """Get FCM tokens for all participants in a ride."""
    stmt = (
        select(User.fcm_token)
        .join(RideParticipant, RideParticipant.user_id == User.user_id)
        .where(RideParticipant.ride_id == ride_id)
        .where(User.fcm_token.is_not(None))
    )
    result = await db.execute(stmt)
    return [row[0] for row in result.all()]


# =============================================================================
# RIDE CRUD
# =============================================================================

@router.post("/", response_model=RideRead)
async def create_ride(
    ride_in: RideCreate,
    current_user: VerifiedDriver,
    db: DBSession
):
    """Create a new ride offer. Requires: driver-verified."""
    stmt = select(Vehicle).where(
        Vehicle.vehicle_id == ride_in.vehicle_id,
        Vehicle.user_id == current_user.user_id
    )
    result = await db.execute(stmt)
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vehicle not found or does not belong to you")

    start_wkt = f"POINT({ride_in.start_location.longitude} {ride_in.start_location.latitude})"
    end_wkt = f"POINT({ride_in.end_location.longitude} {ride_in.end_location.latitude})"

    new_ride = Ride(
        driver_id=current_user.user_id,
        vehicle_id=ride_in.vehicle_id,
        start_location=start_wkt,
        end_location=end_wkt,
        start_address=ride_in.start_address,
        end_address=ride_in.end_address,
        ride_date=ride_in.ride_date,
        ride_time=ride_in.ride_time,
        available_seats=ride_in.available_seats,
        allowed_gender=ride_in.allowed_gender,
        allowed_community=ride_in.allowed_community,
        estimated_fare=ride_in.estimated_fare,
        status=RideStatusEnum.open
    )
    db.add(new_ride)
    await db.flush()
    await db.refresh(new_ride)
    return new_ride


@router.get("/my-rides", response_model=List[RideRead])
async def get_my_rides(
    current_user: CurrentUser,
    db: DBSession
):
    """
    Get all rides the user is involved in (as driver or passenger).
    Sorted by newest first.
    """
    # Subquery: rides where user is a participant
    participant_ride_ids = (
        select(RideParticipant.ride_id)
        .where(RideParticipant.user_id == current_user.user_id)
        .scalar_subquery()
    )

    stmt = (
        select(Ride)
        .where(
            or_(
                Ride.driver_id == current_user.user_id,
                Ride.ride_id.in_(participant_ride_ids)
            )
        )
        .order_by(Ride.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/", response_model=List[RideRead])
async def search_rides(
    current_user: VerifiedUser,
    db: DBSession,
    ride_date: Optional[date] = None,
):
    """Search for available rides. Requires: identity-verified."""
    stmt = select(Ride).where(Ride.status == RideStatusEnum.open)
    if ride_date:
        stmt = stmt.where(Ride.ride_date == ride_date)
    stmt = stmt.order_by(Ride.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


# =============================================================================
# GEOSPATIAL SEARCH (Plan 3.1)
# =============================================================================

@router.get("/search", response_model=List[RideSearchResult])
async def search_rides_geospatial(
    current_user: VerifiedUser,
    db: DBSession,
    lat: float = Query(..., ge=-90, le=90, description="Search center latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Search center longitude"),
    radius_km: float = Query(5.0, ge=0.5, le=50, description="Search radius in km"),
    ride_date: Optional[date] = None,
    search_type: str = Query("pickup", description="Search near: pickup, dropoff, or corridor"),
):
    """
    Geospatial ride search using PostGIS ST_DWithin.
    
    - **pickup**: Rides whose start point is within radius
    - **dropoff**: Rides whose end point is within radius
    - **corridor**: Rides where either start OR end is within radius (approximation)
    
    Results sorted by distance (nearest first) and include distance_km.
    """
    radius_m = radius_km * 1000
    search_point = f"SRID=4326;POINT({lng} {lat})"

    # Choose which column(s) to search against
    if search_type == "pickup":
        location_col = Ride.start_location
        spatial_filter = func.ST_DWithin(Ride.start_location, search_point, radius_m)
    elif search_type == "dropoff":
        location_col = Ride.end_location
        spatial_filter = func.ST_DWithin(Ride.end_location, search_point, radius_m)
    elif search_type == "corridor":
        # MVP corridor: find rides where the point is near either endpoint
        location_col = Ride.start_location  # for distance ordering, use start
        spatial_filter = or_(
            func.ST_DWithin(Ride.start_location, search_point, radius_m),
            func.ST_DWithin(Ride.end_location, search_point, radius_m)
        )
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "search_type must be: pickup, dropoff, or corridor")

    # Build query with distance calculation
    distance_expr = func.ST_Distance(location_col, search_point).label("distance")

    stmt = (
        select(Ride, distance_expr)
        .where(Ride.status == RideStatusEnum.open)
        .where(spatial_filter)
    )

    if ride_date:
        stmt = stmt.where(Ride.ride_date == ride_date)

    stmt = stmt.order_by(distance_expr)

    result = await db.execute(stmt)
    rows = result.all()

    return [
        RideSearchResult(
            ride_id=ride.ride_id,
            start_location=ride.start_location,
            end_location=ride.end_location,
            start_address=ride.start_address,
            end_address=ride.end_address,
            ride_date=ride.ride_date,
            ride_time=ride.ride_time,
            available_seats=ride.available_seats,
            allowed_gender=ride.allowed_gender,
            allowed_community=ride.allowed_community,
            estimated_fare=ride.estimated_fare,
            status=ride.status,
            created_at=ride.created_at,
            distance_km=round(distance / 1000, 2)
        )
        for ride, distance in rows
    ]


@router.get("/distance")
async def calculate_distance(
    current_user: VerifiedUser,
    db: DBSession,
    from_lat: float = Query(..., ge=-90, le=90),
    from_lng: float = Query(..., ge=-180, le=180),
    to_lat: float = Query(..., ge=-90, le=90),
    to_lng: float = Query(..., ge=-180, le=180),
):
    """
    Calculate distance between two geographic points in km.
    Useful for fare estimation.
    """
    point_a = f"SRID=4326;POINT({from_lng} {from_lat})"
    point_b = f"SRID=4326;POINT({to_lng} {to_lat})"

    result = await db.execute(
        select(func.ST_Distance(point_a, point_b).label("distance"))
    )
    distance_m = result.scalar()

    return {
        "distance_km": round(distance_m / 1000, 2),
        "from": {"latitude": from_lat, "longitude": from_lng},
        "to": {"latitude": to_lat, "longitude": to_lng}
    }


@router.get("/{ride_id}", response_model=RideRead)
async def get_ride_details(
    ride_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """Get specific ride details. Requires: identity-verified."""
    return await _get_ride_or_404(db, ride_id)


# =============================================================================
# RIDE REQUESTS (Plan 2.1)
# =============================================================================

@router.post("/{ride_id}/requests", response_model=RideRequestRead, status_code=status.HTTP_201_CREATED)
async def request_to_join(
    ride_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """
    Passenger requests to join a ride.
    Validates: ride is open, not the driver, no duplicate request, seats available.
    """
    ride = await _get_ride_or_404(db, ride_id)

    # Must be open
    if ride.status != RideStatusEnum.open:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ride is not accepting requests")

    # Can't request own ride
    if str(ride.driver_id) == str(current_user.user_id):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot request your own ride")

    # Check duplicate
    existing = await db.execute(
        select(RideRequest).where(
            RideRequest.ride_id == ride_id,
            RideRequest.passenger_id == current_user.user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "You have already requested this ride")

    # Check seat availability (count accepted requests)
    accepted = await db.execute(
        select(RideRequest).where(
            RideRequest.ride_id == ride_id,
            RideRequest.request_status == RideRequestStatusEnum.accepted
        )
    )
    accepted_count = len(accepted.scalars().all())
    if accepted_count >= ride.available_seats:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No seats available")

    # Create request
    request = RideRequest(
        ride_id=ride_id,
        passenger_id=current_user.user_id,
        request_status=RideRequestStatusEnum.pending
    )
    db.add(request)
    await db.flush()

    # Fire-and-forget notification
    try:
        driver = await db.execute(select(User).where(User.user_id == ride.driver_id))
        driver_user = driver.scalar_one_or_none()
        if driver_user and driver_user.fcm_token:
            await notification_service.notify_ride_request(
                driver_user.fcm_token, current_user.full_name, str(ride_id)
            )
    except Exception:
        pass

    return RideRequestRead(
        request_id=request.request_id,
        ride_id=request.ride_id,
        passenger_id=request.passenger_id,
        request_status=request.request_status.value,
        requested_at=request.requested_at
    )


@router.get("/{ride_id}/requests", response_model=List[RideRequestWithUser])
async def get_ride_requests(
    ride_id: UUID,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Driver views all requests for their ride.
    Only the ride owner can see requests.
    """
    ride = await _get_owned_ride(db, ride_id, current_user.user_id)

    # Join with User to get passenger details
    stmt = (
        select(RideRequest, User)
        .join(User, RideRequest.passenger_id == User.user_id)
        .where(RideRequest.ride_id == ride_id)
        .order_by(RideRequest.requested_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    return [
        RideRequestWithUser(
            request_id=req.request_id,
            ride_id=req.ride_id,
            passenger_id=req.passenger_id,
            request_status=req.request_status.value,
            requested_at=req.requested_at,
            passenger_name=user.full_name,
            passenger_phone=user.phone_number
        )
        for req, user in rows
    ]


@router.put("/{ride_id}/requests/{request_id}", response_model=RideRequestRead)
async def action_ride_request(
    ride_id: UUID,
    request_id: UUID,
    body: RideRequestAction,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Driver accepts or rejects a ride request.
    Accept: creates RideParticipant, decrements available_seats.
    Reject: updates request status.
    """
    ride = await _get_owned_ride(db, ride_id, current_user.user_id)

    # Get the request
    result = await db.execute(
        select(RideRequest).where(
            RideRequest.request_id == request_id,
            RideRequest.ride_id == ride_id
        )
    )
    request = result.scalar_one_or_none()
    if not request:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found")

    if request.request_status != RideRequestStatusEnum.pending:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Request already {request.request_status.value}"
        )

    if body.action == "accept":
        # Check seats
        if ride.available_seats <= 0:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "No seats available")

        request.request_status = RideRequestStatusEnum.accepted

        # Create participant
        participant = RideParticipant(
            ride_id=ride_id,
            user_id=request.passenger_id
        )
        db.add(participant)

        # Decrement seats
        ride.available_seats -= 1

    elif body.action == "reject":
        request.request_status = RideRequestStatusEnum.rejected

    await db.flush()

    # Fire-and-forget notification
    try:
        passenger = await db.execute(select(User).where(User.user_id == request.passenger_id))
        passenger_user = passenger.scalar_one_or_none()
        if passenger_user and passenger_user.fcm_token:
            if body.action == "accept":
                await notification_service.notify_request_accepted(
                    passenger_user.fcm_token, str(ride_id)
                )
            else:
                await notification_service.notify_request_rejected(
                    passenger_user.fcm_token, str(ride_id)
                )
    except Exception:
        pass

    return RideRequestRead(
        request_id=request.request_id,
        ride_id=request.ride_id,
        passenger_id=request.passenger_id,
        request_status=request.request_status.value,
        requested_at=request.requested_at
    )


# =============================================================================
# PARTICIPANTS (Plan 2.2)
# =============================================================================

@router.get("/{ride_id}/participants", response_model=List[RideParticipantRead])
async def get_ride_participants(
    ride_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """List confirmed riders for a ride."""
    await _get_ride_or_404(db, ride_id)

    stmt = (
        select(RideParticipant, User)
        .join(User, RideParticipant.user_id == User.user_id)
        .where(RideParticipant.ride_id == ride_id)
        .order_by(RideParticipant.joined_at.asc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    return [
        RideParticipantRead(
            participant_id=p.participant_id,
            user_id=p.user_id,
            full_name=user.full_name,
            phone_number=user.phone_number,
            joined_at=p.joined_at
        )
        for p, user in rows
    ]


# =============================================================================
# RIDE LIFECYCLE (Plan 2.2)
# =============================================================================

@router.post("/{ride_id}/start", response_model=RideRead)
async def start_ride(
    ride_id: UUID,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Driver starts the ride. open → ongoing.
    Requires at least 1 confirmed participant.
    """
    ride = await _get_owned_ride(db, ride_id, current_user.user_id)

    if ride.status != RideStatusEnum.open:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Cannot start ride with status '{ride.status.value}'")

    # Must have at least 1 participant
    participants = await db.execute(
        select(RideParticipant).where(RideParticipant.ride_id == ride_id)
    )
    if not participants.scalars().all():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot start ride with no confirmed participants")

    ride.status = RideStatusEnum.ongoing
    await db.flush()

    # Fire-and-forget notification
    try:
        tokens = await _get_participant_tokens(db, ride_id)
        if tokens:
            await notification_service.notify_ride_starting(tokens, str(ride_id))
    except Exception:
        pass

    await db.refresh(ride)
    return ride


@router.post("/{ride_id}/complete", response_model=RideRead)
async def complete_ride(
    ride_id: UUID,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Driver completes the ride. ongoing → completed.
    Creates RideHistory records for all participants.
    """
    ride = await _get_owned_ride(db, ride_id, current_user.user_id)

    if ride.status != RideStatusEnum.ongoing:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Cannot complete ride with status '{ride.status.value}'")

    ride.status = RideStatusEnum.completed
    now = datetime.now(timezone.utc)

    # Create history records for each participant
    participants = await db.execute(
        select(RideParticipant).where(RideParticipant.ride_id == ride_id)
    )
    for participant in participants.scalars().all():
        history = RideHistory(
            ride_id=ride_id,
            driver_id=ride.driver_id,
            passenger_id=participant.user_id,
            completed_at=now
        )
        db.add(history)

    await db.flush()

    # Fire-and-forget notification
    try:
        tokens = await _get_participant_tokens(db, ride_id)
        if tokens:
            await notification_service.notify_ride_completed(tokens, str(ride_id))
    except Exception:
        pass

    await db.refresh(ride)
    return ride


@router.post("/{ride_id}/cancel", response_model=RideRead)
async def cancel_ride(
    ride_id: UUID,
    current_user: VerifiedDriver,
    db: DBSession
):
    """
    Cancel a ride. open/ongoing → cancelled.
    Auto-rejects all pending requests.
    """
    ride = await _get_owned_ride(db, ride_id, current_user.user_id)

    if ride.status in (RideStatusEnum.completed, RideStatusEnum.cancelled):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Cannot cancel ride with status '{ride.status.value}'"
        )

    ride.status = RideStatusEnum.cancelled

    # Auto-reject pending requests
    pending_requests = await db.execute(
        select(RideRequest).where(
            RideRequest.ride_id == ride_id,
            RideRequest.request_status == RideRequestStatusEnum.pending
        )
    )
    for req in pending_requests.scalars().all():
        req.request_status = RideRequestStatusEnum.rejected

    await db.flush()
    await db.refresh(ride)
    return ride
