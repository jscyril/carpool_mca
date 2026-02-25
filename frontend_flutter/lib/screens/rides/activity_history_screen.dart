import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';
import '../../services/api_service.dart';

/// Shows ride history for the current user (as driver and rider).
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allRides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    final res = await RideApiService.listRides();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data is List) {
          _allRides = res.data as List;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Separate into active vs completed
    final activeRides = _allRides.where((r) {
      final s = r['status'] ?? '';
      return s == 'open' ||
          s == 'driver_arriving' ||
          s == 'driver_arrived' ||
          s == 'ongoing' ||
          s == 'rider_picked_up';
    }).toList();

    final pastRides = _allRides.where((r) {
      final s = r['status'] ?? '';
      return s == 'completed' || s == 'cancelled';
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                      'Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: kPrimary,
                unselectedLabelColor: kMuted,
                indicatorColor: kPrimary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'Active (${activeRides.length})'),
                  Tab(text: 'Past (${pastRides.length})'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRideList(
                          activeRides,
                          cardColor,
                          isEmpty: 'No active rides',
                        ),
                        _buildRideList(
                          pastRides,
                          cardColor,
                          isEmpty: 'No past rides yet',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideList(
    List<dynamic> rides,
    Color cardColor, {
    required String isEmpty,
  }) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 48,
              color: kMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(isEmpty, style: const TextStyle(color: kMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        itemBuilder: (context, index) =>
            _buildRideCard(rides[index], cardColor),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, Color cardColor) {
    final status = ride['status'] ?? '';
    final isActive =
        status == 'open' ||
        status == 'driver_arriving' ||
        status == 'driver_arrived' ||
        status == 'ongoing';

    final statusColor = switch (status) {
      'open' => kPrimary,
      'driver_arriving' || 'driver_arrived' || 'ongoing' => Colors.orange,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
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
          // Status + date
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
                ride['ride_date'] ?? '',
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

          // Fare if available
          if (ride['estimated_fare'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 14, color: kPrimary),
                const SizedBox(width: 4),
                Text(
                  '₹${ride['estimated_fare']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${ride['available_seats'] ?? 0} seats',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
