"""Stub router for identity and driver verification endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/verification", tags=["Verification"])


@router.get("/")
async def verification_status():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
