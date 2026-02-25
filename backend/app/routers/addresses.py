"""
Addresses Router — CRUD for user's saved addresses.

Available to ALL authenticated users (even unverified).
Users can save pickup/drop locations for quick ride creation.
"""
from uuid import UUID
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, update

from core.deps import DBSession, CurrentUser
from db.models.saved_addresses import SavedAddress
from schemas.addresses import AddressCreate, AddressRead, AddressUpdate

router = APIRouter(prefix="/addresses", tags=["Addresses"])


@router.post(
    "/",
    response_model=AddressRead,
    status_code=status.HTTP_201_CREATED
)
async def create_address(
    request: AddressCreate,
    current_user: CurrentUser,
    db: DBSession
):
    """
    Create a saved address.
    Any authenticated user can save addresses (no verification required).
    """
    # If setting as default, unset other defaults first
    if request.is_default:
        await db.execute(
            update(SavedAddress)
            .where(
                SavedAddress.user_id == current_user.user_id,
                SavedAddress.is_default == True
            )
            .values(is_default=False)
        )
    
    address = SavedAddress(
        user_id=current_user.user_id,
        label=request.label,
        address=request.address,
        latitude=request.latitude,
        longitude=request.longitude,
        is_default=request.is_default
    )
    db.add(address)
    await db.flush()
    
    return AddressRead(
        id=address.id,
        label=address.label,
        address=address.address,
        latitude=address.latitude,
        longitude=address.longitude,
        is_default=address.is_default,
        created_at=address.created_at
    )


@router.get(
    "/",
    response_model=list[AddressRead]
)
async def list_addresses(
    current_user: CurrentUser,
    db: DBSession
):
    """List all saved addresses for the current user."""
    result = await db.execute(
        select(SavedAddress)
        .where(SavedAddress.user_id == current_user.user_id)
        .order_by(SavedAddress.is_default.desc(), SavedAddress.created_at.desc())
    )
    addresses = result.scalars().all()
    
    return [
        AddressRead(
            id=addr.id,
            label=addr.label,
            address=addr.address,
            latitude=addr.latitude,
            longitude=addr.longitude,
            is_default=addr.is_default,
            created_at=addr.created_at
        )
        for addr in addresses
    ]


@router.put(
    "/{address_id}",
    response_model=AddressRead
)
async def update_address(
    address_id: UUID,
    request: AddressUpdate,
    current_user: CurrentUser,
    db: DBSession
):
    """Update a saved address. Only the owner can update."""
    result = await db.execute(
        select(SavedAddress).where(
            SavedAddress.id == address_id,
            SavedAddress.user_id == current_user.user_id
        )
    )
    address = result.scalar_one_or_none()
    
    if not address:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Address not found"
        )
    
    # Apply updates
    update_data = request.model_dump(exclude_unset=True)
    
    # If setting as default, unset other defaults first
    if update_data.get("is_default"):
        await db.execute(
            update(SavedAddress)
            .where(
                SavedAddress.user_id == current_user.user_id,
                SavedAddress.is_default == True,
                SavedAddress.id != address_id
            )
            .values(is_default=False)
        )
    
    for field, value in update_data.items():
        setattr(address, field, value)
    
    await db.flush()
    
    return AddressRead(
        id=address.id,
        label=address.label,
        address=address.address,
        latitude=address.latitude,
        longitude=address.longitude,
        is_default=address.is_default,
        created_at=address.created_at
    )


@router.delete(
    "/{address_id}",
    status_code=status.HTTP_204_NO_CONTENT
)
async def delete_address(
    address_id: UUID,
    current_user: CurrentUser,
    db: DBSession
):
    """Delete a saved address. Only the owner can delete."""
    result = await db.execute(
        select(SavedAddress).where(
            SavedAddress.id == address_id,
            SavedAddress.user_id == current_user.user_id
        )
    )
    address = result.scalar_one_or_none()
    
    if not address:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Address not found"
        )
    
    await db.delete(address)


@router.put(
    "/{address_id}/default",
    response_model=AddressRead
)
async def set_default_address(
    address_id: UUID,
    current_user: CurrentUser,
    db: DBSession
):
    """Set an address as the default. Unsets all other defaults."""
    result = await db.execute(
        select(SavedAddress).where(
            SavedAddress.id == address_id,
            SavedAddress.user_id == current_user.user_id
        )
    )
    address = result.scalar_one_or_none()
    
    if not address:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Address not found"
        )
    
    # Unset all defaults
    await db.execute(
        update(SavedAddress)
        .where(
            SavedAddress.user_id == current_user.user_id,
            SavedAddress.is_default == True
        )
        .values(is_default=False)
    )
    
    # Set this one as default
    address.is_default = True
    await db.flush()
    
    return AddressRead(
        id=address.id,
        label=address.label,
        address=address.address,
        latitude=address.latitude,
        longitude=address.longitude,
        is_default=address.is_default,
        created_at=address.created_at
    )
