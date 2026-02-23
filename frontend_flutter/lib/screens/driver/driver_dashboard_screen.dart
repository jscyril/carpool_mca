import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';
import '../../services/api_service.dart';
import 'ride_requests_screen.dart';

/// Driver dashboard: active ride, pending requests, create ride.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _driverProfile;
  List<dynamic> _myRides = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load driver profile
    final profileRes = await DriverProfileApiService.getMyDriverProfile();
    if (profileRes.success) {
      _driverProfile = profileRes.data;
    }

    // Load rides created by this driver
    final ridesRes = await RideApiService.listRides();
    if (ridesRes.success && ridesRes.data is List) {
      _myRides = ridesRes.data as List;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    const Text(
                      'Driver Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _driverProfile != null
                          ? 'Vehicle: ${_driverProfile!['vehicle_number'] ?? 'Not set'}'
                          : 'Set up your driver profile first',
                      style: const TextStyle(color: kMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Quick stats
                    _buildStatsRow(cardColor),
                    const SizedBox(height: 20),

                    // Active rides
                    const Text(
                      'Your Rides',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_myRides.isEmpty)
                      _buildEmptyState(cardColor)
                    else
                      ..._myRides.map(
                        (ride) => _buildRideCard(ride, cardColor),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsRow(Color cardColor) {
    final activeRides = _myRides.where((r) {
      final s = r['status'] ?? '';
      return s == 'open' ||
          s == 'driver_arriving' ||
          s == 'driver_arrived' ||
          s == 'ongoing';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            cardColor,
            icon: Icons.directions_car,
            label: 'Active',
            value: '$activeRides',
            color: kPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            cardColor,
            icon: Icons.history,
            label: 'Total',
            value: '${_myRides.length}',
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            cardColor,
            icon: Icons.event_seat,
            label: 'Seat Limit',
            value: '${_driverProfile?['daily_seat_limit'] ?? '-'}',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    Color cardColor, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.add_road, size: 48, color: kMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'No rides yet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a ride to start accepting passengers',
            style: TextStyle(color: kMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, Color cardColor) {
    final status = ride['status'] ?? 'open';
    final isActive =
        status == 'open' ||
        status == 'driver_arriving' ||
        status == 'driver_arrived' ||
        status == 'ongoing';

    final statusColor = switch (status) {
      'open' => kPrimary,
      'driver_arriving' || 'driver_arrived' || 'ongoing' => Colors.orange,
      'completed' => Colors.green,
      _ => kMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? kPrimary.withValues(alpha: 0.3) : kCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toString().replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${ride['available_seats'] ?? 0} seats left',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route
          Row(
            children: [
              const Icon(Icons.circle, color: kPrimary, size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['start_address'] ?? 'Start',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(width: 2, height: 12, color: kCardBorder),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['end_address'] ?? 'Destination',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final rideId = ride['ride_id']?.toString() ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RideRequestsScreen(rideId: rideId),
                    ),
                  );
                },
                icon: const Icon(Icons.people, size: 18),
                label: const Text('View Requests'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
