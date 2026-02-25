"""
Users Router — User profile management.
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.users import User
from schemas.users import UserRead, UserUpdate


router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserRead)
async def get_my_profile(user: CurrentUser):
    """Get the current authenticated user's profile."""
    return user


@router.put("/me", response_model=UserRead)
async def update_my_profile(
    payload: UserUpdate, user: CurrentUser, db: DBSession
):
    """Update the current user's profile."""
    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.community is not None:
        user.community = payload.community
    if payload.profile_photo_url is not None:
        user.profile_photo_url = payload.profile_photo_url
    if payload.gender is not None:
        user.gender = payload.gender

    await db.flush()
    await db.refresh(user)
    return user
