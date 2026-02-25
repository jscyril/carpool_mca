# TODO.md — Pending Items

> Created by /map on 2026-02-25.

## High Priority
- [ ] Restrict CORS from wildcard `*` to allowed origins before production
- [ ] Add backend tests (pytest + httpx async test client)
- [ ] Resolve auth state overlap between `AuthService` and `ApiService` in Flutter

## Medium Priority
- [ ] Implement Google/Apple sign-in (TODOs in `login.dart`)
- [ ] Wire up image picker for driver photo upload (`driver_details.dart`)
- [ ] Integrate geolocator for location-based address lookup (`personal_details.dart`)
- [ ] Add WebSocket support for real-time ride tracking (currently polling)
- [ ] Set up Alembic for proper DB migrations (currently only `init_db.py`)

## Low Priority
- [ ] Parameterize `baseUrl` in `api_service.dart` via env/flavor config
- [ ] Evaluate state management library (Riverpod/Bloc) for Flutter
- [ ] Add FCM push notification integration (token stored, not used yet)
