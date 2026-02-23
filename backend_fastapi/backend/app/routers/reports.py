"""Stub router for report endpoints."""
from fastapi import APIRouter

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/")
async def list_reports():
    """Placeholder — will be implemented in Phase 4."""
    return {"status": "not_implemented"}
