"""
Emergency Contacts Router — CRUD for user emergency contacts.

Endpoints:
  GET    /emergency-contacts              — List user's emergency contacts
  POST   /emergency-contacts              — Add an emergency contact
  DELETE /emergency-contacts/{contact_id} — Remove an emergency contact
"""
import uuid
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from core.deps import DBSession, CurrentUser
from db.models.emergency_contacts import EmergencyContact
from schemas.emergency_contacts import EmergencyContactCreate, EmergencyContactRead


router = APIRouter(prefix="/emergency-contacts", tags=["Emergency Contacts"])


@router.get("/", response_model=list[EmergencyContactRead])
async def list_emergency_contacts(user: CurrentUser, db: DBSession):
    """List all emergency contacts for the current user."""
    result = await db.execute(
        select(EmergencyContact).where(EmergencyContact.user_id == user.user_id)
    )
    return result.scalars().all()


@router.post("/", response_model=EmergencyContactRead, status_code=status.HTTP_201_CREATED)
async def add_emergency_contact(
    payload: EmergencyContactCreate,
    user: CurrentUser,
    db: DBSession,
):
    """Add a new emergency contact."""
    contact = EmergencyContact(
        contact_id=uuid.uuid4(),
        user_id=user.user_id,
        contact_name=payload.contact_name,
        contact_phone=payload.contact_phone,
        relationship=payload.relationship,
    )
    db.add(contact)
    await db.flush()
    await db.refresh(contact)
    return contact


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_emergency_contact(
    contact_id: uuid.UUID,
    user: CurrentUser,
    db: DBSession,
):
    """Remove an emergency contact (must belong to current user)."""
    result = await db.execute(
        select(EmergencyContact).where(
            EmergencyContact.contact_id == contact_id,
            EmergencyContact.user_id == user.user_id,
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status_code=404, detail="Emergency contact not found")

    await db.delete(contact)
    await db.flush()
