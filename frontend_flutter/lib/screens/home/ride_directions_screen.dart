import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../../services/routing_service.dart';
import '../../services/api_service.dart';
import 'ride_live_screen.dart';

class RideDirectionsScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final LatLng fromLatLng;
  final LatLng toLatLng;

  const RideDirectionsScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromLatLng,
    required this.toLatLng,
  });

  @override
  State<RideDirectionsScreen> createState() => _RideDirectionsScreenState();
}

class _RideDirectionsScreenState extends State<RideDirectionsScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  double? _durationMinutes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      final result = await RoutingService.getRoute(
        widget.fromLatLng,
        widget.toLatLng,
      );

      if (mounted) {
        setState(() {
          _routePoints = result.points;
          _distanceKm = result.distanceKm;
          _durationMinutes = result.durationMinutes;
          _isLoading = false;
        });

        // Fit map to show the full route
        _fitMapToRoute();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load route. Please try again.';
        });
      }
    }
  }

  void _fitMapToRoute() {
    final points = [widget.fromLatLng, widget.toLatLng, ..._routePoints];
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Delay slightly to ensure map is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      }
    });
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.round()} min';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return '${hours}h ${mins}m';
  }

  double? _fareEstimate;

  Future<void> _fetchFareEstimate() async {
    final res = await FareApiService.estimateFare(
      startLat: widget.fromLatLng.latitude,
      startLng: widget.fromLatLng.longitude,
      endLat: widget.toLatLng.latitude,
      endLng: widget.toLatLng.longitude,
    );
    if (res.success && res.data != null && mounted) {
      setState(() {
        _fareEstimate = (res.data['total_fare'] as num?)?.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Route Preview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Location summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildLocationRow(
                  icon: Icons.circle,
                  iconColor: kPrimary,
                  label: 'From',
                  location: widget.fromLocation,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(width: 2, height: 24, color: kCardBorder),
                ),
                _buildLocationRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'To',
                  location: widget.toLocation,
                ),
              ],
            ),
          ),

          // Route info chips
          if (!_isLoading && _distanceKm != null && _durationMinutes != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.straighten,
                    label: '${_distanceKm!.toStringAsFixed(1)} km',
                    color: kPrimary,
                  ),
                  const SizedBox(width: 10),
                  _buildInfoChip(
                    icon: Icons.access_time,
                    label: _formatDuration(_durationMinutes!),
                    color: const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Real Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kCardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: kPrimary),
                          SizedBox(height: 16),
                          Text(
                            'Loading route...',
                            style: TextStyle(
                              color: kMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.orange,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: kMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _fetchRoute();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.fromLatLng,
                        initialZoom: 12,
                      ),
                      children: [
                        // OSM tile layer
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.uniride.carpool',
                        ),

                        // Route polyline
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5.0,
                                color: kPrimary,
                              ),
                            ],
                          ),

                        // Markers
                        MarkerLayer(
                          markers: [
                            // Start marker
                            Marker(
                              point: widget.fromLatLng,
                              width: 90,
                              height: 50,
                              child: _buildMapPin(
                                icon: Icons.trip_origin,
                                color: kPrimary,
                                label: 'Start',
                              ),
                            ),
                            // End marker
                            Marker(
                              point: widget.toLatLng,
                              width: 90,
                              height: 50,
                              child: _buildMapPin(
                                icon: Icons.location_on,
                                color: Colors.red,
                                label: 'End',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),

          // Bottom action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: kCardBorder)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated fare',
                      style: TextStyle(color: kMuted),
                    ),
                    Text(
                      _fareEstimate != null
                          ? '₹${_fareEstimate!.round()}'
                          : '₹--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Request Ride',
                  icon: Icons.directions_car,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RideLiveScreen(
                          fromLocation: widget.fromLocation,
                          toLocation: widget.toLocation,
                          fromLatLng: widget.fromLatLng,
                          toLatLng: widget.toLatLng,
                          distanceKm: _distanceKm,
                          durationMinutes: _durationMinutes,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
