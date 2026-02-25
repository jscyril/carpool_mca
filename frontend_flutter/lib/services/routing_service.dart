import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Route data returned from OSRM.
class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Service for fetching driving routes via the free OSRM public API.
class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Fetch a driving route between [start] and [end].
  /// Returns route polyline points, distance in km, and duration in minutes.
  static Future<RouteResult> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'UniRide-CarpoolApp/1.0'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }

    final data = json.decode(response.body);

    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('No route found between the given locations.');
    }

    final route = data['routes'][0];
    final geometry = route['geometry'];
    final coordinates = geometry['coordinates'] as List;

    // GeoJSON coordinates are [longitude, latitude]
    final points = coordinates
        .map<LatLng>(
          (coord) => LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          ),
        )
        .toList();

    final distanceMeters = (route['distance'] as num).toDouble();
    final durationSeconds = (route['duration'] as num).toDouble();

    return RouteResult(
      points: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: durationSeconds / 60.0,
    );
  }
}
