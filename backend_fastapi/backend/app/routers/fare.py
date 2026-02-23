"""
Fare Router — Distance-based fare calculation.

Uses a hardcoded campus distance matrix and a simple formula:
  fare = base_fare + (per_km_rate × distance_km)
  per_rider_fare = fare / num_riders

For non-campus routes, uses Haversine distance as approximation.
"""
import math
from typing import Optional
from fastapi import APIRouter, Query
from pydantic import BaseModel


router = APIRouter(prefix="/fare", tags=["Fare"])

# ─── Constants ───────────────────────────────────────────────────────────────
BASE_FARE = 20.0       # ₹20 base fare
PER_KM_RATE = 8.0      # ₹8 per km
MIN_FARE = 30.0        # Minimum fare

# ─── Campus locations (lat, lng) ─────────────────────────────────────────────
CAMPUSES = {
    "central":      {"name": "Christ University Central Campus",      "lat": 12.9346, "lng": 77.6069},
    "kengeri":      {"name": "Christ University Kengeri Campus",      "lat": 12.9063, "lng": 77.4828},
    "yeshwantpur":  {"name": "Christ University Yeshwantpur Campus",  "lat": 13.0206, "lng": 77.5381},
    "bannerghatta": {"name": "Christ University Bannerghatta Campus", "lat": 12.8441, "lng": 77.5993},
}

# ─── Pre-computed campus-to-campus distances (km, road approx) ───────────────
# These are approximate road distances, not Haversine
CAMPUS_DISTANCES = {
    ("central", "kengeri"):      22.0,
    ("central", "yeshwantpur"):   7.5,
    ("central", "bannerghatta"): 12.0,
    ("kengeri", "yeshwantpur"):  20.0,
    ("kengeri", "bannerghatta"): 18.0,
    ("yeshwantpur", "bannerghatta"): 18.5,
}


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Compute Haversine distance in km between two points."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _get_campus_distance(campus_a: str, campus_b: str) -> Optional[float]:
    """Look up pre-computed campus distance (order-independent)."""
    key = tuple(sorted([campus_a, campus_b]))
    return CAMPUS_DISTANCES.get(key)


def _calculate_fare(distance_km: float, num_riders: int = 1) -> dict:
    """Calculate fare based on distance and number of riders."""
    total_fare = max(MIN_FARE, BASE_FARE + PER_KM_RATE * distance_km)
    per_rider = round(total_fare / max(1, num_riders), 2)
    return {
        "distance_km": round(distance_km, 2),
        "total_fare": round(total_fare, 2),
        "per_rider_fare": per_rider,
        "num_riders": num_riders,
        "base_fare": BASE_FARE,
        "per_km_rate": PER_KM_RATE,
    }


class FareEstimateResponse(BaseModel):
    distance_km: float
    total_fare: float
    per_rider_fare: float
    num_riders: int
    base_fare: float
    per_km_rate: float


@router.get("/estimate", response_model=FareEstimateResponse)
async def estimate_fare(
    start_lat: float = Query(..., description="Pickup latitude"),
    start_lng: float = Query(..., description="Pickup longitude"),
    end_lat: float = Query(..., description="Destination latitude"),
    end_lng: float = Query(..., description="Destination longitude"),
    num_riders: int = Query(1, ge=1, le=10, description="Number of riders to split fare"),
):
    """
    Estimate fare between two points.

    If both points are near known campuses, uses the pre-computed road distance.
    Otherwise falls back to Haversine distance × 1.3 (road factor).
    """
    # Try to match points to campuses (within 2km radius)
    start_campus = None
    end_campus = None
    for key, campus in CAMPUSES.items():
        if _haversine_km(start_lat, start_lng, campus["lat"], campus["lng"]) < 2.0:
            start_campus = key
        if _haversine_km(end_lat, end_lng, campus["lat"], campus["lng"]) < 2.0:
            end_campus = key

    distance_km = None
    if start_campus and end_campus and start_campus != end_campus:
        distance_km = _get_campus_distance(start_campus, end_campus)

    if distance_km is None:
        # Fallback: Haversine × road factor
        distance_km = _haversine_km(start_lat, start_lng, end_lat, end_lng) * 1.3

    return _calculate_fare(distance_km, num_riders)


class CampusInfo(BaseModel):
    key: str
    name: str
    lat: float
    lng: float


class CampusRoute(BaseModel):
    from_campus: str
    to_campus: str
    distance_km: float
    estimated_fare: float


class CampusMatrixResponse(BaseModel):
    campuses: list[CampusInfo]
    routes: list[CampusRoute]


@router.get("/campus-matrix", response_model=CampusMatrixResponse)
async def get_campus_matrix():
    """Return the full campus distance & fare matrix."""
    campuses = [
        CampusInfo(key=k, name=v["name"], lat=v["lat"], lng=v["lng"])
        for k, v in CAMPUSES.items()
    ]
    routes = []
    for (a, b), dist in CAMPUS_DISTANCES.items():
        fare_info = _calculate_fare(dist, 1)
        routes.append(CampusRoute(
            from_campus=a,
            to_campus=b,
            distance_km=dist,
            estimated_fare=fare_info["total_fare"],
        ))
    return CampusMatrixResponse(campuses=campuses, routes=routes)
