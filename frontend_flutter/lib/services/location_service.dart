import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for GPS location access, geocoding, and address persistence.
class LocationService {
  // SharedPreferences keys for saved address
  static const String _savedAddressKey = 'savedPickupAddress';
  static const String _savedLatKey = 'savedPickupLat';
  static const String _savedLngKey = 'savedPickupLng';

  /// Check and request location permissions, then return current position.
  /// Uses last known position as fast fallback, then fetches fresh GPS.
  static Future<LatLng> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permissions are permanently denied. Please enable them in Settings.',
      );
    }

    // Try last known position first for speed
    final lastKnown = await Geolocator.getLastKnownPosition();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // If fresh GPS times out, fall back to last known
      if (lastKnown != null) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
      throw LocationException(
        'Could not determine your location. Please try again or enter an address manually.',
      );
    }
  }

  /// Stream live position updates. Useful for real-time ride tracking.
  static Stream<LatLng> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).map((pos) => LatLng(pos.latitude, pos.longitude));
  }

  /// Reverse geocode a [LatLng] to a human-readable address using Nominatim.
  static Future<String> reverseGeocode(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}'
        '&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'UniRide-CarpoolApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
    } catch (_) {
      // Fallback to coordinates
    }
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  /// Forward geocode an address string to a list of possible [LatLng] results.
  /// Uses viewbox bias toward Karnataka/Bangalore for more relevant results.
  /// Returns a list of {displayName, lat, lng} maps.
  static Future<List<Map<String, dynamic>>> forwardGeocode(String query) async {
    try {
      // Viewbox covers Karnataka roughly: SW(11.5,74.0) to NE(18.5,78.5)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&countrycodes=in'
        '&viewbox=74.0,18.5,78.5,11.5&bounded=0',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'UniRide-CarpoolApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map<Map<String, dynamic>>(
              (item) => {
                'displayName': item['display_name'] as String,
                'lat': double.parse(item['lat'] as String),
                'lng': double.parse(item['lon'] as String),
              },
            )
            .toList();
      }
    } catch (_) {
      // Return empty on failure
    }
    return [];
  }

  /// Checks whether a LatLng is roughly within India.
  /// Used to detect emulator default locations (e.g. Mountain View, CA).
  static bool isInIndia(LatLng position) {
    // India bounding box: lat 6.5–35.5, lng 68–97.5
    return position.latitude >= 6.5 &&
        position.latitude <= 35.5 &&
        position.longitude >= 68.0 &&
        position.longitude <= 97.5;
  }

  // ---- Saved Address Persistence ----

  /// Save pickup address with coordinates.
  static Future<void> savePickupAddress({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedAddressKey, address);
    await prefs.setDouble(_savedLatKey, lat);
    await prefs.setDouble(_savedLngKey, lng);
  }

  /// Load saved pickup address. Returns null if none saved.
  static Future<Map<String, dynamic>?> getSavedPickupAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_savedAddressKey);
    final lat = prefs.getDouble(_savedLatKey);
    final lng = prefs.getDouble(_savedLngKey);

    if (address != null && lat != null && lng != null) {
      return {'address': address, 'lat': lat, 'lng': lng};
    }
    return null;
  }

  /// Check if a saved address exists.
  static Future<bool> hasSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedAddressKey) != null;
  }
}

/// Custom exception for location errors.
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
