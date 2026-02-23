import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../../services/routing_service.dart';
import '../../services/ride_simulation_service.dart';

/// Live tracking screen for an active ride.
///
/// Simulates driver movement along the OSRM route in two phases:
///   Phase 1: Driver heading to pickup (rider sees driver approaching)
///   Phase 2: Pickup → Destination (both see trip progress)
///
/// A temporary FAB toggles between rider and driver view.
class RideLiveScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final LatLng fromLatLng; // pickup
  final LatLng toLatLng; // destination
  final double? distanceKm;
  final double? durationMinutes;

  const RideLiveScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromLatLng,
    required this.toLatLng,
    this.distanceKm,
    this.durationMinutes,
  });

  @override
  State<RideLiveScreen> createState() => _RideLiveScreenState();
}

class _RideLiveScreenState extends State<RideLiveScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // View mode
  bool _isDriverView = false;

  // Simulation
  RideSimulationService? _simulation;
  LatLng? _driverPosition;
  double _progress = 0.0;
  SimulationPhase _currentPhase = SimulationPhase.driverToPickup;

  // Routes
  List<LatLng> _driverToPickupRoute = [];
  List<LatLng> _pickupToDestRoute = [];
  bool _isLoadingRoute = true;

  // OTP
  final String _pickupOtp = _generateOtp();
  final TextEditingController _otpController = TextEditingController();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static String _generateOtp() {
    return '${Random().nextInt(9000) + 1000}';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSimulation();
  }

  @override
  void dispose() {
    _simulation?.dispose();
    _pulseController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _initSimulation() async {
    // Simulate a driver starting position (offset from pickup)
    final driverStart = LatLng(
      widget.fromLatLng.latitude + 0.015 + Random().nextDouble() * 0.01,
      widget.fromLatLng.longitude - 0.01 + Random().nextDouble() * 0.01,
    );

    try {
      // Fetch route: driver → pickup
      final toPickup = await RoutingService.getRoute(
        driverStart,
        widget.fromLatLng,
      );
      // Fetch route: pickup → destination
      final toDest = await RoutingService.getRoute(
        widget.fromLatLng,
        widget.toLatLng,
      );

      if (!mounted) return;

      setState(() {
        _driverToPickupRoute = toPickup.points;
        _pickupToDestRoute = toDest.points;
        _driverPosition = driverStart;
        _isLoadingRoute = false;
      });

      // Start phase 1 simulation
      _startPhase1();
      _fitMapToRoute(_driverToPickupRoute);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startPhase1() {
    _simulation = RideSimulationService(
      routePoints: List.from(_driverToPickupRoute),
      speedKmh: 50.0,
      onUpdate: (pos, progress, phase) {
        if (mounted) {
          setState(() {
            _driverPosition = pos;
            _progress = progress;
            _currentPhase = phase;
          });
        }
      },
      onPhaseComplete: () {
        if (mounted) {
          setState(() {
            _currentPhase = SimulationPhase.pickupReached;
            _driverPosition = widget.fromLatLng;
          });
        }
      },
    );
    _simulation!.start();
  }

  void _startPhase2() {
    setState(() {
      _currentPhase = SimulationPhase.riderToDestination;
      _progress = 0.0;
    });

    _simulation?.dispose();
    _simulation = RideSimulationService(
      routePoints: List.from(_pickupToDestRoute),
      speedKmh: 40.0,
      onUpdate: (pos, progress, phase) {
        if (mounted) {
          setState(() {
            _driverPosition = pos;
            _progress = progress;
            _currentPhase = SimulationPhase.riderToDestination;
          });
        }
      },
      onPhaseComplete: () {
        if (mounted) {
          setState(() {
            _currentPhase = SimulationPhase.arrived;
            _driverPosition = widget.toLatLng;
          });
        }
      },
    );
    _simulation!.start();
    _fitMapToRoute(_pickupToDestRoute);
  }

  void _verifyOtp() {
    if (_otpController.text.trim() == _pickupOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ OTP Verified! Rider picked up.'),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // Start phase 2 after short delay
      Future.delayed(const Duration(milliseconds: 800), _startPhase2);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✗ Invalid OTP. Try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _driverArrived() {
    _simulation?.stop();
    setState(() {
      _currentPhase = SimulationPhase.pickupReached;
      _driverPosition = widget.fromLatLng;
    });
  }

  void _completeRide() {
    _simulation?.stop();
    setState(() {
      _currentPhase = SimulationPhase.arrived;
      _driverPosition = widget.toLatLng;
    });
  }

  void _fitMapToRoute(List<LatLng> points) {
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
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: _isLoadingRoute
            ? _buildLoading()
            : Column(
                children: [
                  _buildTopBar(cardColor),
                  _buildStatusCard(cardColor),
                  Expanded(child: _buildMap()),
                  _buildBottomPanel(cardColor),
                ],
              ),
      ),
      floatingActionButton: _isLoadingRoute
          ? null
          : FloatingActionButton.small(
              onPressed: () => setState(() => _isDriverView = !_isDriverView),
              backgroundColor: _isDriverView
                  ? const Color(0xFF6366F1)
                  : kPrimary,
              child: Icon(
                _isDriverView ? Icons.person : Icons.directions_car,
                color: Colors.white,
                size: 20,
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: kPrimary),
          SizedBox(height: 16),
          Text(
            'Setting up ride...',
            style: TextStyle(
              color: kMuted,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Finding best route',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: kCardBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _simulation?.stop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDriverView ? 'DRIVER VIEW' : 'RIDER VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: _isDriverView ? const Color(0xFF6366F1) : kPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getPhaseTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildProgressBadge(),
        ],
      ),
    );
  }

  Widget _buildProgressBadge() {
    final pct = (_progress * 100).round();
    final color = _currentPhase == SimulationPhase.arrived
        ? Colors.green
        : kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _currentPhase == SimulationPhase.arrived
            ? '✓ Done'
            : _currentPhase == SimulationPhase.pickupReached
            ? 'At Pickup'
            : '$pct%',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusCard(Color cardColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            label: 'Pickup',
            location: widget.fromLocation,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 16, color: kCardBorder),
          ),
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            label: 'Destination',
            location: widget.toLocation,
          ),
          if (widget.distanceKm != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoChip(
                  Icons.straighten,
                  '${widget.distanceKm!.toStringAsFixed(1)} km',
                  kPrimary,
                ),
                const SizedBox(width: 8),
                if (widget.durationMinutes != null)
                  _buildInfoChip(
                    Icons.access_time,
                    '${widget.durationMinutes!.round()} min',
                    const Color(0xFF6366F1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    final currentRoute =
        _currentPhase == SimulationPhase.riderToDestination ||
            _currentPhase == SimulationPhase.arrived
        ? _pickupToDestRoute
        : _driverToPickupRoute;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: widget.fromLatLng, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.uniride.carpool',
          ),
          // Route polyline
          if (currentRoute.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: currentRoute,
                  strokeWidth: 5.0,
                  color: kPrimary.withValues(alpha: 0.7),
                ),
              ],
            ),
          // Markers
          MarkerLayer(
            markers: [
              // Pickup marker
              Marker(
                point: widget.fromLatLng,
                width: 90,
                height: 50,
                child: _buildMapPin(
                  icon: Icons.trip_origin,
                  color: kPrimary,
                  label: 'Pickup',
                ),
              ),
              // Destination marker
              Marker(
                point: widget.toLatLng,
                width: 90,
                height: 50,
                child: _buildMapPin(
                  icon: Icons.flag,
                  color: Colors.red,
                  label: 'Dest',
                ),
              ),
              // Driver/car marker
              if (_driverPosition != null)
                Marker(
                  point: _driverPosition!,
                  width: 50,
                  height: 50,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: _pulseAnimation.value * 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: _buildPhaseAction(),
    );
  }

  Widget _buildPhaseAction() {
    switch (_currentPhase) {
      case SimulationPhase.driverToPickup:
        return _isDriverView
            ? _buildDriverNavigatingToPickup()
            : _buildRiderWaitingForDriver();

      case SimulationPhase.pickupReached:
        return _isDriverView ? _buildDriverOtpEntry() : _buildRiderShowOtp();

      case SimulationPhase.riderToDestination:
        return _isDriverView
            ? _buildDriverNavigatingToDest()
            : _buildRiderEnRoute();

      case SimulationPhase.arrived:
        return _buildRideComplete();
    }
  }

  // --- Rider views ---

  Widget _buildRiderWaitingForDriver() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver is on the way',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'ETA: ${_estimateEta()} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: kPrimary,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildRiderShowOtp() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: kPrimary, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Your driver has arrived!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share this code with your driver',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _pickupOtp,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiderEnRoute() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to ${widget.toLocation}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ETA: ${_estimateDestEta()} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: const Color(0xFF6366F1),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // --- Driver views ---

  Widget _buildDriverNavigatingToPickup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigate to pickup',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'ETA: ${_estimateEta()} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: const Color(0xFF6366F1),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: "I've Arrived",
          icon: Icons.location_on,
          onPressed: _driverArrived,
        ),
      ],
    );
  }

  Widget _buildDriverOtpEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Enter rider\'s OTP to confirm pickup',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCardBorder),
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '• • • •',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _verifyOtp,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverNavigatingToDest() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.flag, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to ${widget.toLocation}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ETA: ${_estimateDestEta()} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: kPrimary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: 'Complete Ride',
          icon: Icons.check_circle,
          onPressed: _completeRide,
        ),
      ],
    );
  }

  Widget _buildRideComplete() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.celebration, color: Colors.green, size: 36),
              const SizedBox(height: 8),
              Text(
                _isDriverView ? 'Ride Complete!' : 'You\'ve arrived!',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.toLocation,
                style: const TextStyle(color: kMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AuthButton(
                label: 'Done',
                icon: Icons.home,
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helpers ---

  String _getPhaseTitle() {
    switch (_currentPhase) {
      case SimulationPhase.driverToPickup:
        return _isDriverView ? 'Navigate to Pickup' : 'Driver Approaching';
      case SimulationPhase.pickupReached:
        return _isDriverView ? 'Verify Rider' : 'Driver Arrived';
      case SimulationPhase.riderToDestination:
        return 'En Route';
      case SimulationPhase.arrived:
        return 'Arrived';
    }
  }

  int _estimateEta() {
    final remaining = 1.0 - _progress;
    // Rough estimate: 5-10 min total for pickup
    return max(1, (remaining * 8).round());
  }

  int _estimateDestEta() {
    final remaining = 1.0 - _progress;
    final totalMin = widget.durationMinutes ?? 15;
    return max(1, (remaining * totalMin).round());
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 10,
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

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
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
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
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
