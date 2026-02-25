from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from typing import List
from uuid import UUID

from core.deps import DBSession, CurrentUser, VerifiedDriver
from db.models.vehicles import Vehicle
from schemas.vehicles import VehicleCreate, VehicleRead

router = APIRouter(
    prefix="/vehicles",
    tags=["Vehicles"]
)

@router.post("/", response_model=VehicleRead, status_code=status.HTTP_201_CREATED)
async def add_vehicle(
    vehicle_in: VehicleCreate,
    current_user: VerifiedDriver,  # Must be driver-verified to add vehicles
    db: DBSession
):
    """
    Add a new vehicle to the user's profile.
    Requires: identity-verified + driver-verified.
    """
    new_vehicle = Vehicle(
        user_id=current_user.user_id,
        **vehicle_in.model_dump()
    )
    
    try:
        db.add(new_vehicle)
        await db.flush()
        await db.refresh(new_vehicle)
        return new_vehicle
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vehicle already registered or invalid data"
        )

@router.get("/", response_model=List[VehicleRead])
async def get_my_vehicles(
    current_user: CurrentUser,  # Any authenticated user can view their vehicles
    db: DBSession
):
    """
    List all vehicles owned by the current user.
    """
    stmt = select(Vehicle).where(Vehicle.user_id == current_user.user_id)
    result = await db.execute(stmt)
    return result.scalars().all()

@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: UUID,
    current_user: VerifiedDriver,  # Must be driver-verified to delete vehicles
    db: DBSession
):
    """
    Delete a vehicle.
    Requires: identity-verified + driver-verified.
    """
    stmt = select(Vehicle).where(
        Vehicle.vehicle_id == vehicle_id,
        Vehicle.user_id == current_user.user_id
    )
    result = await db.execute(stmt)
    vehicle = result.scalar_one_or_none()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found"
        )
        
    await db.delete(vehicle)
