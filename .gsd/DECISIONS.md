# DECISIONS.md — Architecture Decision Records

> Auto-created by /map on 2026-02-25. Add ADRs here as design decisions are made.

## ADR-001 — Passwordless OTP Authentication
**Date:** (project inception)  
**Decision:** Use phone OTP for login/registration instead of password-based auth.  
**Rationale:** Simpler for college students; no password management; phone ownership is a proxy for identity.  
**Consequences:** Requires reliable SMS delivery; risk if phone is lost.

## ADR-002 — Tiered Verification Model
**Date:** (project inception)  
**Decision:** Four-level verification: phone → email → identity → driver.  
**Rationale:** Progressive trust; passengers need basic verification, drivers need thorough vetting.  
**Consequences:** More complex onboarding UX; more backend state to manage.

## ADR-003 — PostGIS for Geospatial Storage
**Date:** (project inception)  
**Decision:** Store ride start/end as `Geography(POINT, SRID=4326)` via GeoAlchemy2.  
**Rationale:** Enables accurate distance calculations and proximity queries natively in PostgreSQL.  
**Consequences:** Requires PostGIS extension on the database server.

## ADR-004 — Pluggable External Services
**Date:** (project inception)  
**Decision:** SMS, Email, OCR, and Vehicle Verification providers are switchable via env vars (`PROVIDER=console|real`).  
**Rationale:** Allows local development without real API keys; easy to swap providers.  
**Consequences:** More service abstraction code to maintain.
