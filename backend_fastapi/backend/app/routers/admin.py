"""Stub router for admin endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/")
async def admin_dashboard():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
