"""Stub router for SOS alert endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/sos", tags=["SOS"])


@router.get("/")
async def sos_status():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
