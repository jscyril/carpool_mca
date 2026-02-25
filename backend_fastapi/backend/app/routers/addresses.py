"""Stub router for saved address endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/addresses", tags=["Addresses"])


@router.get("/")
async def list_addresses():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
