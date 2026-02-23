import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Phases of the ride simulation.
enum SimulationPhase {
  driverToPickup,
  pickupReached,
  riderToDestination,
  arrived,
}

/// Callback with current simulation state.
typedef SimulationCallback =
    void Function(
      LatLng currentPosition,
      double progress,
      SimulationPhase phase,
    );

/// Client-side ride simulation service.
///
/// Interpolates a marker along a list of route points at a given speed,
/// calling [onUpdate] on each tick. Supports two legs:
///   1. Driver → Pickup
///   2. Pickup → Destination
class RideSimulationService {
  final List<LatLng> routePoints;
  final double speedKmh;
  final SimulationCallback onUpdate;
  final VoidCallback? onPhaseComplete;

  Timer? _timer;
  int _currentIndex = 0;
  SimulationPhase _phase = SimulationPhase.driverToPickup;
  bool _isPaused = false;

  static const int _tickMs = 500; // update every 500ms

  RideSimulationService({
    required this.routePoints,
    this.speedKmh = 40.0,
    required this.onUpdate,
    this.onPhaseComplete,
  });

  SimulationPhase get phase => _phase;
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Start or resume the simulation.
  void start() {
    if (routePoints.length < 2) return;
    _isPaused = false;

    // Calculate how many points to advance per tick based on speed
    // Average distance between consecutive points
    final totalDist = _totalDistance();
    final totalPoints = routePoints.length;
    final metersPerTick = (speedKmh * 1000.0 / 3600.0) * (_tickMs / 1000.0);
    final avgDistPerPoint = totalDist / totalPoints;
    final pointsPerTick = max(1, (metersPerTick / avgDistPerPoint).round());

    _timer = Timer.periodic(Duration(milliseconds: _tickMs), (_) {
      if (_isPaused) return;

      _currentIndex += pointsPerTick;

      if (_currentIndex >= routePoints.length - 1) {
        _currentIndex = routePoints.length - 1;
        onUpdate(routePoints[_currentIndex], 1.0, _phase);
        stop();
        onPhaseComplete?.call();
        return;
      }

      final progress = _currentIndex / (routePoints.length - 1);
      onUpdate(routePoints[_currentIndex], progress, _phase);
    });
  }

  /// Pause the simulation.
  void pause() {
    _isPaused = true;
  }

  /// Stop and dispose the timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset for a new leg of the journey.
  void resetWithNewRoute(List<LatLng> newPoints, SimulationPhase newPhase) {
    stop();
    routePoints.clear();
    routePoints.addAll(newPoints);
    _currentIndex = 0;
    _phase = newPhase;
  }

  /// Set phase externally (e.g., after OTP verification).
  void setPhase(SimulationPhase newPhase) {
    _phase = newPhase;
  }

  /// Compute total distance in meters between all consecutive route points.
  double _totalDistance() {
    const distance = Distance();
    double total = 0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      total += distance.as(
        LengthUnit.Meter,
        routePoints[i],
        routePoints[i + 1],
      );
    }
    return total;
  }

  /// Dispose resources.
  void dispose() {
    stop();
  }
}

/// Typedef for compatibility (dart:async doesn't export VoidCallback).
typedef VoidCallback = void Function();
