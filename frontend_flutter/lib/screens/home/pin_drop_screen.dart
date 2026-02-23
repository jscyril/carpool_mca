import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../../services/location_service.dart';

/// Full-screen map where user drops a pin to set precise pickup location.
///
/// Returns a Map with 'lat', 'lng', 'address' when the user confirms.
class PinDropScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const PinDropScreen({super.key, this.initialLocation});

  @override
  State<PinDropScreen> createState() => _PinDropScreenState();
}

class _PinDropScreenState extends State<PinDropScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String _address = 'Tap on the map to drop a pin';
  bool _isLoadingAddress = false;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _reverseGeocode(widget.initialLocation!);
    } else {
      _loadCurrentLocation();
    }
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _selectedLocation = loc;
          _isLoadingGps = false;
        });
        _mapController.move(loc, 16.0);
        _reverseGeocode(loc);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGps = false);
        // Default to Bangalore center
        final fallback = LatLng(12.9716, 77.5946);
        setState(() => _selectedLocation = fallback);
        _mapController.move(fallback, 13.0);
      }
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isLoadingAddress = true);
    try {
      final addr = await LocationService.reverseGeocode(point);
      if (mounted) {
        setState(() {
          _address = addr;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address =
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedLocation = point);
    _reverseGeocode(point);
  }

  void _confirmLocation() {
    if (_selectedLocation == null) return;
    Navigator.of(context).pop({
      'lat': _selectedLocation!.latitude,
      'lng': _selectedLocation!.longitude,
      'address': _address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(bottom: BorderSide(color: kCardBorder)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Drop Pin for Pickup',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (_isLoadingGps)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation ?? LatLng(12.9716, 77.5946),
                  initialZoom: _selectedLocation != null ? 16.0 : 13.0,
                  onTap: _onMapTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.uniride.carpool',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 60,
                          height: 60,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_pin,
                                color: kPrimary,
                                size: 40,
                              ),
                              Text(
                                'Pickup',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Bottom panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: kCardBorder)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: kPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup Location',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _isLoadingAddress
                                ? const Text(
                                    'Getting address...',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: kMuted,
                                    ),
                                  )
                                : Text(
                                    _address,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loadCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('My Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AuthButton(
                          label: 'Confirm Pickup',
                          icon: Icons.check,
                          onPressed: _selectedLocation != null
                              ? _confirmLocation
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
