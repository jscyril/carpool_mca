"""
Vehicles Router — CRUD for user's vehicles.
"""
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.vehicles import Vehicle
from schemas.vehicles import VehicleCreate, VehicleRead


router = APIRouter(prefix="/vehicles", tags=["Vehicles"])


@router.get("/", response_model=list[VehicleRead])
async def list_my_vehicles(user: CurrentUser, db: DBSession):
    """List all vehicles owned by the current user."""
    result = await db.execute(
        select(Vehicle).where(Vehicle.user_id == user.user_id)
    )
    return result.scalars().all()


@router.post("/", response_model=VehicleRead, status_code=status.HTTP_201_CREATED)
async def add_vehicle(
    payload: VehicleCreate, user: CurrentUser, db: DBSession
):
    """Register a new vehicle for the current user."""
    # Check for duplicate plate number
    existing = await db.execute(
        select(Vehicle).where(Vehicle.vehicle_number == payload.vehicle_number)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Vehicle with this number already registered.",
        )

    vehicle = Vehicle(
        vehicle_id=uuid.uuid4(),
        user_id=user.user_id,
        vehicle_type=payload.vehicle_type,
        vehicle_number=payload.vehicle_number.upper(),
    )
    db.add(vehicle)
    await db.flush()
    await db.refresh(vehicle)
    return vehicle


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: uuid.UUID, user: CurrentUser, db: DBSession
):
    """Delete a vehicle owned by the current user."""
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.vehicle_id == vehicle_id,
            Vehicle.user_id == user.user_id,
        )
    )
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or does not belong to you.",
        )
    await db.delete(vehicle)
    await db.flush()
