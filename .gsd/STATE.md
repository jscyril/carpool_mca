# STATE.md — Project Memory

> Last updated: 2026-02-25

## Project
**UniRide** — Christ University Carpooling Platform  
**Repo:** `carpool-mca`  
**Backend:** `backend_fastapi/backend/` (FastAPI + PostgreSQL + PostGIS)  
**Frontend:** `frontend_flutter/` (Flutter, Dart SDK ^3.10.1)

## Last Session Summary
Codebase mapping complete via `/map`.
- 14 API routers identified
- 15+ database models mapped
- 22 Flutter screens catalogued
- 10 technical debt items documented
- ARCHITECTURE.md and STACK.md created

## Current Status
Project initialized with GSD. No phases planned yet.

## Active Decisions
- All external services (SMS, Email, OCR, Vehicle Verification) run in `console` mode by default — switch via env vars
- Database uses async SQLAlchemy + asyncpg; `init_db.py` for schema creation (no Alembic)

## Known Blockers
- No tests anywhere (backend or frontend)
- CORS wildcard must be restricted before production
- No WebSocket/real-time layer for ride tracking
