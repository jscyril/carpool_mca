"""Stub router for emergency contact endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/emergency-contacts", tags=["Emergency Contacts"])


@router.get("/")
async def list_emergency_contacts():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
