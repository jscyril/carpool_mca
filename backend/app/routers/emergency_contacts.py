"""
Emergency Contacts Router — CRUD for emergency contacts.

Endpoints:
- POST /emergency-contacts/ — Add contact (max 3 per user)
- GET /emergency-contacts/ — List my contacts
- PUT /emergency-contacts/{contact_id} — Update contact
- DELETE /emergency-contacts/{contact_id} — Delete contact
"""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select, func
from typing import List
from uuid import UUID

from core.deps import DBSession, VerifiedUser
from db.models.emergency_contacts import EmergencyContact
from schemas.emergency_contacts import (
    EmergencyContactCreate, EmergencyContactRead, EmergencyContactUpdate
)

router = APIRouter(
    prefix="/emergency-contacts",
    tags=["Emergency Contacts"]
)

MAX_CONTACTS = 3


@router.post("/", response_model=EmergencyContactRead, status_code=status.HTTP_201_CREATED)
async def add_emergency_contact(
    body: EmergencyContactCreate,
    current_user: VerifiedUser,
    db: DBSession
):
    """Add an emergency contact. Max 3 per user."""
    # Check limit
    count_result = await db.execute(
        select(func.count(EmergencyContact.contact_id))
        .where(EmergencyContact.user_id == current_user.user_id)
    )
    count = count_result.scalar() or 0
    if count >= MAX_CONTACTS:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Maximum {MAX_CONTACTS} emergency contacts allowed"
        )

    contact = EmergencyContact(
        user_id=current_user.user_id,
        contact_name=body.contact_name,
        contact_phone=body.contact_phone,
        relationship=body.relationship
    )
    db.add(contact)
    await db.flush()
    await db.refresh(contact)
    return contact


@router.get("/", response_model=List[EmergencyContactRead])
async def list_emergency_contacts(
    current_user: VerifiedUser,
    db: DBSession
):
    """List my emergency contacts."""
    result = await db.execute(
        select(EmergencyContact)
        .where(EmergencyContact.user_id == current_user.user_id)
    )
    return result.scalars().all()


@router.put("/{contact_id}", response_model=EmergencyContactRead)
async def update_emergency_contact(
    contact_id: UUID,
    body: EmergencyContactUpdate,
    current_user: VerifiedUser,
    db: DBSession
):
    """Update an emergency contact (owner only)."""
    result = await db.execute(
        select(EmergencyContact).where(
            EmergencyContact.contact_id == contact_id,
            EmergencyContact.user_id == current_user.user_id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Contact not found")

    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(contact, key, value)

    await db.flush()
    await db.refresh(contact)
    return contact


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_emergency_contact(
    contact_id: UUID,
    current_user: VerifiedUser,
    db: DBSession
):
    """Delete an emergency contact (owner only)."""
    result = await db.execute(
        select(EmergencyContact).where(
            EmergencyContact.contact_id == contact_id,
            EmergencyContact.user_id == current_user.user_id
        )
    )
    contact = result.scalar_one_or_none()
    if not contact:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Contact not found")

    await db.delete(contact)
    await db.flush()
