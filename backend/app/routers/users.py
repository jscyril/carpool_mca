from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import Annotated
from pydantic import BaseModel, Field

from core.deps import get_db, get_current_active_user, DBSession, CurrentUser
from db.models.users import User
from schemas.users import UserRead, UserUpdate

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)

@router.get("/me", response_model=UserRead)
async def get_my_profile(
    current_user: Annotated[User, Depends(get_current_active_user)]
):
    """
    Get current logged-in user's profile.
    """
    return current_user

@router.put("/me", response_model=UserRead)
async def update_my_profile(
    user_update: UserUpdate,
    current_user: Annotated[User, Depends(get_current_active_user)],
    db: Annotated[AsyncSession, Depends(get_db)]
):
    """
    Update profile details.
    """
    # Prepare update data (exclude unset fields)
    update_data = user_update.model_dump(exclude_unset=True)
    
    if not update_data:
        return current_user

    # Execute Update
    stmt = (
        update(User)
        .where(User.user_id == current_user.user_id)
        .values(**update_data)
        .returning(User)
    )
    
    result = await db.execute(stmt)
    updated_user = result.scalar_one()
    await db.commit()
    
    return updated_user


# =============================================================================
# FCM TOKEN (Plan 4.2)
# =============================================================================

class FCMTokenUpdate(BaseModel):
    """FCM token registration request."""
    fcm_token: str = Field(..., max_length=255)


@router.post("/me/fcm-token")
async def register_fcm_token(
    body: FCMTokenUpdate,
    current_user: CurrentUser,
    db: DBSession
):
    """Register device FCM token for push notifications."""
    current_user.fcm_token = body.fcm_token
    await db.flush()
    return {"message": "FCM token registered"}


@router.delete("/me/fcm-token")
async def clear_fcm_token(
    current_user: CurrentUser,
    db: DBSession
):
    """Clear FCM token (on logout)."""
    current_user.fcm_token = None
    await db.flush()
    return {"message": "FCM token cleared"}

