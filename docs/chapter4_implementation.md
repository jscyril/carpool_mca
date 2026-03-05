# Chapter 4 — Implementation

> **Application:** UniRide — A Secure Carpooling Platform for College Students

---

## 4.1 Implementation Approaches

### Overview

UniRide is implemented as a **full-stack mobile application** using a modern, decoupled architecture. The backend exposes a RESTful API built with **FastAPI (Python)**, and the mobile frontend is built with **Flutter (Dart)**. Both components communicate over HTTP with JSON payloads and JWT-based authentication.

### Architecture Model

The application follows a **3-tier layered architecture**:

```
┌─────────────────────────────────┐
│       Presentation Layer        │  Flutter Mobile App
│  (Screens, Widgets, Services)   │
└────────────────┬────────────────┘
                 │ HTTP / REST (JSON + JWT)
┌────────────────▼────────────────┐
│        Application Layer        │  FastAPI Backend
│   (Routers, Schemas, Services)  │
└────────────────┬────────────────┘
                 │ SQLAlchemy ORM (Async)
┌────────────────▼────────────────┐
│          Data Layer             │  PostgreSQL + PostGIS
│   (Models, Migrations, DB)      │
└─────────────────────────────────┘
```

### Development Phases and Procedure

| Phase                      | Objective                   | Procedure                                                                                                  |
| -------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Phase 1 — Auth**         | Passwordless login/signup   | Design OTP flow → Implement backend SMS + token system → Wire Flutter auth screens → End-to-end test       |
| **Phase 2 — Rides**        | Ride creation and booking   | Define ride lifecycle enums → Build ride router → Implement seat management → Connect Flutter ride screens |
| **Phase 3 — Fare**         | Automatic price calculation | Define campus coordinates → Build distance matrix → Implement Haversine fallback → Expose REST endpoint    |
| **Phase 4 — Safety**       | Ratings, SOS, reports       | Create rating model → Implement post-ride rating → Add emergency contacts → Build SOS trigger system       |
| **Phase 5 — Verification** | Identity & driver checks    | Design tiered verification model → Build verification router → File upload flow for identity docs          |

### Key Architectural Decisions

1. **Passwordless OTP Authentication (ADR-001):** Users log in using phone OTP instead of passwords—no credential management overhead, safer for students sharing devices.

2. **Tiered Verification (ADR-002):** User trust is built progressively—phone → email → identity document → driver license. Passengers need basic verification; drivers need thorough vetting.

3. **PostGIS for Geospatial Data (ADR-003):** Ride start/end coordinates are stored as `Geography(POINT, SRID=4326)` in PostgreSQL using the PostGIS extension, enabling accurate distance calculations natively in the database.

4. **Pluggable External Services (ADR-004):** SMS, Email, OCR, and Vehicle Verification providers are configured via environment variables (`PROVIDER=console|real`), so the app can be developed and tested locally without real API keys.

5. **Async FastAPI + SQLAlchemy:** All backend operations use Python's `asyncio` to prevent blocking I/O, ensuring the server can handle concurrent riders and drivers efficiently.

6. **Stateless API:** The backend is fully stateless—all session state is encoded in JWT tokens stored on the client (Flutter `SharedPreferences`).

### Technology Stack

| Component               | Technology                          |
| ----------------------- | ----------------------------------- |
| Mobile Frontend         | Flutter 3.x (Dart)                  |
| Backend API             | FastAPI 0.11x (Python 3.12)         |
| Database                | PostgreSQL 15 + PostGIS             |
| ORM                     | SQLAlchemy 2.x (Async)              |
| Authentication          | JWT (PyJWT), Phone OTP              |
| HTTP Client (Flutter)   | `http` package                      |
| Local Storage (Flutter) | `shared_preferences`                |
| Geospatial              | GeoAlchemy2, Shapely                |
| Maps                    | Flutter Google Maps / OpenStreetMap |

---

## 4.2 Coding Standards

### Backend (Python / FastAPI)

1. **PEP 8 Compliance:** All Python code follows PEP 8 conventions — snake_case for variables and functions, PascalCase for classes, 4-space indentation.

2. **Type Hints Everywhere:** Every function parameter and return value is type-annotated using Python's `typing` module and Pydantic models:

   ```python
   async def create_ride(payload: RideCreate, user: CurrentUser, db: DBSession) -> RideRead:
   ```

3. **Docstrings for all Endpoints:** Every router function has a triple-quoted docstring describing the endpoint's purpose, inputs, and behavior.

4. **Pydantic for Schema Validation:** All request and response bodies are defined as Pydantic `BaseModel` classes in the `schemas/` directory — separate from the SQLAlchemy ORM models in `db/models/`.

5. **Dependency Injection:** Common dependencies (database session, current authenticated user, client IP) are injected via FastAPI's `Depends()` system from `core/deps.py`.

6. **Modular Routers:** Each feature area has its own router file (e.g., `auth.py`, `rides.py`, `fare.py`) registered on the main `FastAPI` app instance.

7. **Enum-based State Machines:** Application states (ride status, verification status, vehicle type) are implemented as Python `str` + `enum.Enum` subclasses to enforce valid values at the database and API layer.

8. **Error Handling via HTTPException:** All error responses use `fastapi.HTTPException` with semantic HTTP status codes (400, 403, 404, 409, 429) rather than ad-hoc error strings.

9. **Async/Await Throughout:** All database queries use `await db.execute(...)` — no synchronous blocking calls.

10. **Environment-based Configuration:** Secrets, provider flags, and database URLs are loaded from `.env` files via a `Settings` Pydantic model in `core/config.py` using `lru_cache` for performance.

### Frontend (Dart / Flutter)

1. **Dart Effective Style:** Follows the [Dart style guide](https://dart.dev/guides/language/effective-dart) — `camelCase` for variables and functions, `PascalCase` for classes, double-quoted strings.

2. **Widget Decomposition:** Screens are broken into small, focused widget classes. Private widgets (not exported) are prefixed with `_` (e.g., `_LoginSignupScreen`, `_ContentCard`).

3. **Separation of Concerns:**
   - `lib/screens/` — UI only (no business logic)
   - `lib/services/` — All HTTP API calls, token management

4. **Service Classes with Static Methods:** API calls are grouped into static service classes per domain (e.g., `AuthApiService`, `RideApiService`, `FareApiService`) for easy consumption from any widget.

5. **Typed API Response Wrapper:** All HTTP calls return an `ApiResponse` object with `success`, `statusCode`, `data`, and `error` fields — preventing unhandled exceptions from propagating into the UI.

6. **`const` Constructors:** Immutable widgets use `const` constructors for performance — instructing Flutter to never rebuild them unnecessarily.

7. **State Management with `setState`:** Screens use standard `StatefulWidget` + `setState` for local UI state (loading, error messages, step navigation). No third-party state management library.

8. **Haptic Feedback on Actions:** Important user actions (form submissions, button presses) trigger `HapticFeedback.lightImpact()` for tactile response.

9. **`SafeArea` & Responsive Layouts:** All screens use `SafeArea` to avoid system UI intrusions. Widths are calculated from `MediaQuery.of(context).size` for device-independence.

10. **SharedPreferences for Token Storage:** JWT access tokens are stored using `SharedPreferences` — the platform-native key-value store.

---

## 4.3 Coding Details

### 4.3.1 Backend — Application Entry Point (`main.py`)

```python
"""
College Carpool API - Main Application Entry Point

Sets up the FastAPI app, registers CORS middleware, and mounts all routers.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.config import get_settings

# Import models so SQLAlchemy registers them before any table creation
from db.models import users, vehicles, rides, ride_requests, ...

# Import all feature routers
from routers import auth, rides as rides_router, fare as fare_router, ...

settings = get_settings()

# Create the FastAPI application instance
app = FastAPI(
    title=settings.APP_NAME,
    description="A secure carpooling platform for college students",
    version="1.0.0",
    docs_url="/docs",     # Interactive Swagger UI
    redoc_url="/redoc"    # Alternative ReDoc UI
)

# Allow cross-origin requests (configure for production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register each feature router — each has its own URL prefix and tag
app.include_router(auth.router)          # /auth/*
app.include_router(rides_router.router)  # /rides/*
app.include_router(fare_router.router)   # /fare/*
app.include_router(ratings_router.router) # /ratings/*
# ... (13 additional routers)

@app.get("/health")
async def health():
    """Health check for load balancers."""
    return {"status": "ok"}
```

### 4.3.2 Backend — Database Enums (`db/enums.py`)

```python
import enum

# Gender enum — used for user profiles and ride gender filters
class GenderEnum(str, enum.Enum):
    male   = "male"
    female = "female"
    other  = "other"

# Ride lifecycle states — drives the full ride status machine
class RideStatusEnum(str, enum.Enum):
    open            = "open"           # Ride created, accepting requests
    driver_arriving = "driver_arriving" # Driver is on the way to pickup
    driver_arrived  = "driver_arrived"  # Driver has reached pickup point
    rider_picked_up = "rider_picked_up" # Rider confirmed via OTP
    ongoing         = "ongoing"         # Ride in progress
    completed       = "completed"       # Ride completed
    cancelled       = "cancelled"       # Ride was cancelled

# Status for ride join requests from passengers
class RideRequestStatusEnum(str, enum.Enum):
    pending  = "pending"   # Awaiting driver action
    accepted = "accepted"  # Driver accepted the rider
    rejected = "rejected"  # Driver rejected the rider

# Allowed passenger gender for a ride — drivers can restrict
class AllowedGenderEnum(str, enum.Enum):
    any    = "any"
    male   = "male"
    female = "female"

# Document verification pipeline status
class VerificationStatusEnum(str, enum.Enum):
    pending   = "pending"   # No document submitted
    submitted = "submitted" # Document uploaded, awaiting review
    verified  = "verified"  # Admin/system approved
    rejected  = "rejected"  # Admin rejected the document
```

### 4.3.3 Backend — OTP Authentication Router (`routers/auth.py`)

The registration flow is a 3-step OTP process:

```python
"""
Authentication Router — Passwordless OTP-based authentication.

Registration Flow:
  1. POST /auth/phone/send-otp      → Send OTP to phone number
  2. POST /auth/phone/verify-otp    → Verify OTP → get phone_verified_token
  3. POST /auth/register            → Create account with phone_verified_token

Login Flow:
  1. POST /auth/login/send-otp      → Send OTP to registered phone
  2. POST /auth/login/verify-otp    → Verify OTP → get access_token (JWT)
"""

@router.post("/phone/send-otp", response_model=PhoneSendOTPResponse)
async def send_phone_otp(request: PhoneSendOTPRequest, req: Request, db: DBSession):
    """
    Step 1 of Registration: Send OTP to a new phone number.
    - Checks phone is not already registered
    - Rate limited: max 5 requests/hour, 60-second cooldown
    - OTP expires in 5 minutes
    """
    # Reject if phone number is already in the users table
    existing = await db.execute(select(User).where(User.phone_number == request.phone))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered.")

    otp_service = OTPService(db)
    sms_service = SMSService()

    # Create OTP session (stores hashed OTP in DB) and get the plaintext OTP
    session, plain_otp = await otp_service.create_otp_session(
        identifier=request.phone,
        identifier_type=IdentifierType.phone,
        ip_address=get_client_ip(req)
    )

    # Send the 6-digit OTP via SMS provider (console/SMS gateway)
    sent = await sms_service.send_otp(request.phone, plain_otp)
    if not sent:
        raise HTTPException(status_code=500, detail="Failed to send OTP.")

    # Return a short-lived session_token (JWT) encapsulating the session_id
    session_token = create_phone_session_token(str(session.session_id), request.phone)
    return PhoneSendOTPResponse(session_token=session_token, expires_at=session.expires_at)


@router.post("/register", response_model=RegisterResponse)
async def register(request: RegisterRequest, db: DBSession):
    """
    Step 3: Create new user account after phone verification.
    - Requires valid phone_verified_token from step 2
    - No password — phone ownership IS the credential
    - Returns an access_token (JWT) for immediate session start
    """
    # Decode and validate the phone_verified_token JWT
    phone_payload = decode_token(request.phone_verified_token, TokenType.PHONE_VERIFIED)
    if not phone_payload or not phone_payload.get("verified"):
        raise HTTPException(status_code=400, detail="Invalid phone verification token.")

    phone = phone_payload.get("phone")

    # Create the user record — email and college ID added later via verification flow
    user = User(
        user_id=uuid.uuid4(),
        full_name=request.full_name,
        phone_number=phone,
        gender=request.gender,
        is_phone_verified=True,    # Phone is verified via OTP
        is_email_verified=False,   # Email verified separately
        is_identity_verified=False, # Identity document verified by admin
        is_driver_verified=False,   # Driver license verified separately
        is_active=True
    )
    db.add(user)
    await db.flush()  # Write to DB within the current transaction

    # Issue a permanent access token — the user is now logged in
    access_token = create_access_token(str(user.user_id))
    return RegisterResponse(access_token=access_token, user=UserResponse(...))
```

### 4.3.4 Backend — Ride Lifecycle Router (`routers/rides.py`)

```python
"""
Rides Router — Multi-passenger ride lifecycle management.
Handles creation, searching, join requests, status transitions, and OTP pickup.
"""

def _generate_otp() -> str:
    """Generate a 4-digit numeric OTP for per-rider pickup verification."""
    return "".join(random.choices(string.digits, k=4))


@router.post("/", response_model=RideRead, status_code=201)
async def create_ride(payload: RideCreate, user: CurrentUser, db: DBSession):
    """
    Driver creates a new ride.
    - Verifies the vehicle belongs to the authenticated driver
    - Stores start/end as PostGIS Geography points (SRID=4326)
    """
    # Ensure vehicle exists and belongs to the current driver
    vehicle = (await db.execute(
        select(Vehicle).where(Vehicle.vehicle_id == payload.vehicle_id,
                              Vehicle.user_id == user.user_id)
    )).scalar_one_or_none()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found.")

    # Convert lat/lng to PostGIS Geography format using Shapely
    from geoalchemy2.shape import from_shape
    from shapely.geometry import Point

    ride = Ride(
        ride_id=uuid.uuid4(),
        driver_id=user.user_id,
        start_location=from_shape(
            Point(payload.start_location.longitude, payload.start_location.latitude), srid=4326
        ),
        end_location=from_shape(
            Point(payload.end_location.longitude, payload.end_location.latitude), srid=4326
        ),
        available_seats=payload.available_seats,
        allowed_gender=payload.allowed_gender,  # Gender filter set by driver
        estimated_fare=payload.estimated_fare,
    )
    db.add(ride)
    await db.flush()
    return ride


@router.put("/{ride_id}/requests/{request_id}")
async def handle_ride_request(ride_id, request_id, payload: RideRequestAction,
                               user: CurrentUser, db: DBSession):
    """
    Driver accepts or rejects a passenger's join request.
    On acceptance:
      - A RideParticipant record is created with the rider's pickup info
      - A unique 4-digit OTP is assigned to each rider for pickup verification
      - Available seats count is decremented
    """
    if payload.action == "accept":
        if ride.available_seats <= 0:
            raise HTTPException(status_code=400, detail="No seats available.")

        req.request_status = RideRequestStatusEnum.accepted

        # Each accepted rider gets their own pickup OTP
        participant = RideParticipant(
            participant_id=uuid.uuid4(),
            ride_id=ride_id,
            user_id=req.passenger_id,
            pickup_lat=req.pickup_lat,
            pickup_lng=req.pickup_lng,
            pickup_otp=_generate_otp(),  # Unique OTP per rider
        )
        db.add(participant)
        ride.available_seats -= 1  # Decrement available seat count
    else:
        req.request_status = RideRequestStatusEnum.rejected

    await db.flush()
    return {"message": f"Request {payload.action}ed", "status": req.request_status.value}
```

### 4.3.5 Backend — Fare Calculation Router (`routers/fare.py`)

```python
"""
Fare Router — Distance-based fare calculation.

Formula: fare = base_fare + (per_km_rate × distance_km)
         per_rider_fare = total_fare / num_riders

For Christ University campus-to-campus routes, pre-computed road distances
are used. For other routes, Haversine distance × 1.3 (road factor) is used.
"""

# Fare constants
BASE_FARE   = 20.0   # ₹20 flat starting fare
PER_KM_RATE = 8.0    # ₹8 additional per kilometre
MIN_FARE    = 30.0   # Minimum fare floor regardless of distance

# Known campus coordinates (lat, lng)
CAMPUSES = {
    "central":      {"lat": 12.9346, "lng": 77.6069},  # Christ Central Campus
    "kengeri":      {"lat": 12.9063, "lng": 77.4828},  # Christ Kengeri Campus
    "yeshwantpur":  {"lat": 13.0206, "lng": 77.5381},  # Christ Yeshwantpur Campus
    "bannerghatta": {"lat": 12.8441, "lng": 77.5993},  # Christ Bannerghatta Campus
}

# Approximate road distances between campus pairs (km)
CAMPUS_DISTANCES = {
    ("central", "kengeri"):      22.0,
    ("central", "yeshwantpur"):   7.5,
    ("central", "bannerghatta"): 12.0,
    ("kengeri", "yeshwantpur"):  20.0,
    ("kengeri", "bannerghatta"): 18.0,
    ("yeshwantpur", "bannerghatta"): 18.5,
}


def _haversine_km(lat1, lng1, lat2, lng2) -> float:
    """
    Compute the great-circle distance (Haversine formula) between two
    GPS coordinates in kilometres.
    """
    R = 6371.0  # Earth's radius in km
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    # Haversine formula
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _calculate_fare(distance_km: float, num_riders: int = 1) -> dict:
    """
    Calculate total and per-rider fare.
    Applies a minimum fare floor of ₹30.
    """
    total_fare = max(MIN_FARE, BASE_FARE + PER_KM_RATE * distance_km)
    per_rider  = round(total_fare / max(1, num_riders), 2)  # Split evenly
    return {
        "distance_km":    round(distance_km, 2),
        "total_fare":     round(total_fare, 2),
        "per_rider_fare": per_rider,
        "num_riders":     num_riders,
    }


@router.get("/estimate", response_model=FareEstimateResponse)
async def estimate_fare(start_lat, start_lng, end_lat, end_lng, num_riders=1):
    """
    Estimate fare between any two GPS points.
    If both points match a known campus (within 2km), uses the pre-computed
    road distance table for accuracy. Otherwise falls back to Haversine × 1.3.
    """
    # Snap each GPS point to the nearest campus within 2km radius
    start_campus = end_campus = None
    for key, campus in CAMPUSES.items():
        if _haversine_km(start_lat, start_lng, campus["lat"], campus["lng"]) < 2.0:
            start_campus = key
        if _haversine_km(end_lat, end_lng, campus["lat"], campus["lng"]) < 2.0:
            end_campus = key

    # Use pre-computed campus distance if both endpoints are known campuses
    distance_km = None
    if start_campus and end_campus and start_campus != end_campus:
        key = tuple(sorted([start_campus, end_campus]))
        distance_km = CAMPUS_DISTANCES.get(key)

    # Fallback: Haversine distance × 1.3 road correction factor
    if distance_km is None:
        distance_km = _haversine_km(start_lat, start_lng, end_lat, end_lng) * 1.3

    return _calculate_fare(distance_km, num_riders)
```

### 4.3.6 Backend — Ratings Router (`routers/ratings.py`)

```python
"""
Ratings Router — Post-ride ratings and user rating summaries.
Both drivers and passengers can rate each other after a ride completes.
"""

@router.post("/{ride_id}", response_model=RatingRead, status_code=201)
async def submit_rating(ride_id, payload: RatingCreate, user: CurrentUser, db: DBSession):
    """
    Submit a 1-5 star rating after a ride.
    Guards:
      - Prevents self-rating
      - Confirms rater was part of the ride (driver or passenger)
      - Prevents duplicate rating for the same ride+user pair
    """
    # Self-rating check
    if payload.rated_user_id == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot rate yourself.")

    # Confirm the rater participated in this ride
    is_driver = ride.driver_id == user.user_id
    if not is_driver:
        participant = (await db.execute(
            select(RideParticipant).where(
                RideParticipant.ride_id == ride_id,
                RideParticipant.user_id == user.user_id,
            )
        )).scalar_one_or_none()
        if not participant:
            raise HTTPException(status_code=403, detail="You were not part of this ride.")

    # Check for duplicate rating
    existing = (await db.execute(
        select(Rating).where(
            Rating.ride_id == ride_id,
            Rating.rater_id == user.user_id,
            Rating.rated_user_id == payload.rated_user_id,
        )
    )).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="Already rated this user for this ride.")

    # Create and persist the rating
    rating = Rating(
        rating_id=uuid.uuid4(),
        ride_id=ride_id,
        rater_id=user.user_id,
        rated_user_id=payload.rated_user_id,
        rating_value=payload.rating_value,  # Integer 1-5
        comment=payload.comment,            # Optional text comment
    )
    db.add(rating)
    await db.flush()
    return rating


@router.get("/user/{user_id}", response_model=UserRatingSummary)
async def get_user_rating_summary(user_id, db: DBSession):
    """
    Get the average rating and total rating count for a user.
    Uses SQL AVG() and COUNT() aggregation functions for efficiency.
    """
    result = await db.execute(
        select(
            func.avg(Rating.rating_value).label("average_rating"),
            func.count(Rating.rating_id).label("total_ratings"),
        ).where(Rating.rated_user_id == user_id)
    )
    row = result.one()
    return UserRatingSummary(
        user_id=user_id,
        average_rating=round(float(row.average_rating or 0), 1),
        total_ratings=int(row.total_ratings),
    )
```

### 4.3.7 Backend — College Student Model (`db/models/college_students.py`)

```python
"""
CollegeStudent model — stores institutional data for verified students.
Linked 1:1 to a User via foreign key.
After registration, users can submit their college email and ID here
for verification by the admin.
"""
import uuid
from sqlalchemy import String, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base


class CollegeStudent(Base):
    __tablename__ = "college_students"

    # UUID primary key — decoupled from user_id
    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # Foreign key links this record to the users table (one user = one college record)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), unique=True, nullable=False
    )

    # College institutional email (e.g. name@mca.christuniversity.in)
    college_email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)

    # Optional: student ID card number for cross-verification
    college_id_number: Mapped[str | None] = mapped_column(String(50))

    # Academic details — captured during verification
    department: Mapped[str | None] = mapped_column(String(100))
    program: Mapped[str | None] = mapped_column(String(100))  # e.g., MCA, MBA

    # Timestamp when admin verified the record
    verified_at: Mapped[str | None] = mapped_column(TIMESTAMP(timezone=True))

    # Auto-populated creation timestamp
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
```

---

### 4.3.8 Frontend — API Service Layer (`services/api_service.dart`)

```dart
/// Base API service — provides HTTP methods with auth headers and error handling.
/// All HTTP communication with the FastAPI backend passes through this class.
class ApiService {
  /// Backend base URL — uses 10.0.2.2 on Android emulator to reach host machine
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// Retrieve JWT access token stored in SharedPreferences
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Store JWT access token after successful login/registration
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  /// Build HTTP headers — adds Authorization: Bearer <token> if auth=true
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Generic HTTP GET — returns ApiResponse with success/error info
  static Future<ApiResponse> get(String path, {bool auth = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      // Handle no network / server not running
      return ApiResponse(success: false, statusCode: 0,
          error: 'Cannot connect to server. Make sure the backend is running.');
    }
  }

  /// Generic HTTP POST — body is JSON-encoded Map
  static Future<ApiResponse> post(String path,
      {Map<String, dynamic>? body, bool auth = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      return ApiResponse(success: false, statusCode: 0,
          error: 'Cannot connect to server. Make sure the backend is running.');
    }
  }
}

/// Domain-specific Auth API — wraps ApiService for /auth/* endpoints
class AuthApiService {
  /// POST /auth/phone/send-otp — initiate phone signup
  static Future<ApiResponse> sendPhoneOtp(String phone) async {
    return ApiService.post('/auth/phone/send-otp', body: {'phone': phone});
  }

  /// POST /auth/phone/verify-otp — verify OTP, receive phone_verified_token
  static Future<ApiResponse> verifyPhoneOtp(String sessionToken, String otp) async {
    return ApiService.post('/auth/phone/verify-otp',
        body: {'session_token': sessionToken, 'otp': otp});
  }

  /// POST /auth/register — complete registration, receive access_token
  static Future<ApiResponse> register({
    required String phoneVerifiedToken,
    required String fullName,
    required String gender,
    String? community,
  }) async {
    return ApiService.post('/auth/register', body: {
      'phone_verified_token': phoneVerifiedToken,
      'full_name': fullName,
      'gender': gender,
      if (community != null) 'community': community,
    });
  }
}

/// Domain-specific Fare API — wraps ApiService for /fare/* endpoints
class FareApiService {
  /// GET /fare/estimate — estimate fare between two GPS coordinates
  static Future<ApiResponse> estimateFare({
    required double startLat, required double startLng,
    required double endLat,   required double endLng,
    int numRiders = 1,
  }) async {
    final query = '?start_lat=$startLat&start_lng=$startLng'
        '&end_lat=$endLat&end_lng=$endLng&num_riders=$numRiders';
    return ApiService.get('/fare/estimate$query', auth: false);
  }
}
```

### 4.3.9 Frontend — Auth Screen Navigator (`screens/auth/login.dart`)

```dart
/// AuthScreen manages the multi-step authentication flow using AnimatedSwitcher
/// The screen acts as a state machine coordinator — no actual UI is rendered here.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthStep _currentStep = AuthStep.loginSignup; // Current step in the flow
  bool _isSignUp = false;     // Login vs Signup mode
  String _sessionToken = '';  // JWT from /send-otp, passed to /verify-otp
  String _phoneVerifiedToken = ''; // JWT from /verify-otp, passed to /register

  /// Called when user submits phone number — triggers OTP dispatch
  void _onPhoneSubmit(String phone, String countryCode, bool isSignUp) async {
    final fullPhone = '$countryCode$phone';

    // Route to correct API endpoint depending on login vs signup
    final response = isSignUp
        ? await AuthApiService.sendPhoneOtp(fullPhone)
        : await AuthApiService.loginSendOtp(fullPhone);

    if (response.success) {
      setState(() {
        _sessionToken = response.data!['session_token'] ?? '';
        _isSignUp = isSignUp;
        _currentStep = AuthStep.otp; // Advance to OTP screen
      });
    } else {
      // Show error SnackBar on failure
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error ?? 'Failed to send OTP'),
                 backgroundColor: Colors.red.shade600),
      );
    }
  }

  /// Called after OTP is verified — routes to next appropriate step
  void _onOtpVerified({String? phoneVerifiedToken, String? accessToken,
                        Map<String, dynamic>? userData}) async {
    if (_isSignUp && phoneVerifiedToken != null) {
      // Signup: store verified token, proceed to fill personal details
      setState(() => _phoneVerifiedToken = phoneVerifiedToken);
      _navigateToStep(AuthStep.personalDetails);
    } else if (accessToken != null) {
      // Login: store access token and navigate to home screen
      await ApiService.saveAccessToken(accessToken);
      _onAuthComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == AuthStep.loginSignup, // Only allow back at first step
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300), // Smooth screen transitions
        transitionBuilder: (child, animation) {
          // Slide in from the right for each new step
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        child: _buildCurrentStep(), // Render only the active step widget
      ),
    );
  }
}

/// The 4 distinct steps in the authentication funnel
enum AuthStep { loginSignup, otp, personalDetails, driverDetails }
```

---

## 4.3 Screen Shots

> The following screens demonstrate the key user flows of the UniRide application.

### Input Screens

#### 4.3.1 Login / Sign Up Screen

The entry point of the app. Users toggle between **Log In** and **Sign Up** tabs, enter their phone number, and tap the OTP button. Sign Up additionally requires Terms & Conditions agreement.

> _Screen shows: Tab switcher (Log In / Sign Up), phone number input field with country code selector, OTP send button, social login options._

---

#### 4.3.2 OTP Verification Screen

After submitting the phone number, users are navigated to this screen to enter the 6-digit OTP received via SMS. A countdown timer shows OTP validity, and a **Resend OTP** option is available.

> _Screen shows: 6-box OTP digit input, countdown timer, resend button, phone number displayed for reference._

---

#### 4.3.3 Personal Details Screen

First-time registrants fill in their **full name**, **gender**, and **college community** after phone verification. This data is submitted to `POST /auth/register`.

> _Screen shows: Full name field, gender dropdown selector, community field, Continue button._

---

#### 4.3.4 Driver Details Screen

Optional step for users who want to also drive. Collects **vehicle type** (2-wheeler / 4-wheeler) and **vehicle registration number**. Users can skip to proceed as a passenger only.

> _Screen shows: Vehicle type selector, registration number input, Register as Driver button, Skip button._

---

### Output Screens

#### 4.3.5 Home Screen

After login, users land on the home screen showing a map of campus locations. The **Where to?** search bar initiates ride search. Bottom navigation provides access to Rides, Profile, and History.

> _Screen shows: Map view with campus markers, search bar, bottom navigation bar._

---

#### 4.3.6 Ride Search & Booking Screen

Riders enter a pickup location from their saved addresses, current GPS location, or manual input. The destination is selected from the 4 Christ University campuses. A fare estimate is shown before confirming the request.

> _Screen shows: From/To location fields, campus destination selector, fare estimate card, Book Ride button._

---

#### 4.3.7 Live Ride Tracking Screen

Once a ride is confirmed and in progress, riders see the driver's position on a real-time map. The screen shows the rider's pickup OTP (used by the driver to confirm pickup), ETA, and fare details.

> _Screen shows: Live map with driver marker, OTP display box, ETA chip, fare amount._

---

#### 4.3.8 Driver Ride Management Screen

Drivers see the list of pending join requests with passenger names, pickup addresses, and gender. They can **Accept** or **Reject** each request. After accepting, the screen transitions to the active ride view where they can see each rider's OTP.

> _Screen shows: Request cards with Accept/Reject buttons, accepted participants list with pickup OTPs._

---

#### 4.3.9 Rate Ride Screen

After a ride is marked complete, both driver and riders are prompted to rate each other on a 1-5 star scale with an optional text comment.

> _Screen shows: Star rating widget, comment text area, Submit Rating button._

---

#### 4.3.10 Activity / Ride History Screen

Users can view all past rides — as driver or passenger — with date, route, fare, and their post-ride rating for that ride.

> _Screen shows: List of ride history cards showing route, date, fare, and rating._

---

#### 4.3.11 Profile & Safety Screen

Users can view and edit their profile (name, photo, community). The **Safety** section allows managing emergency contacts and viewing past SOS alerts. Emergency contact details are shown here.

> _Screen shows: Profile card, emergency contacts list, Add Contact FAB, SOS history._

---

_End of Chapter 4 — Implementation_
