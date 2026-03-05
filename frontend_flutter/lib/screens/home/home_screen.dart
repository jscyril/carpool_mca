import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../profile/user_profile.dart';
import '../settings/settings_screen.dart';
import '../driver/driver_dashboard_screen.dart';
import '../rides/activity_history_screen.dart';
import '../../services/location_service.dart';
import 'location_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  String _selectedQuickDestination = 'Campus';
  LatLng? _currentLocation;
  bool _isLocating = true;
  final MapController _mapController = MapController();

  final List<String> _quickDestinations = ['Campus', 'Home', 'Library'];

  // Default center: Bangalore
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _isLocating = false;
        });
        // Animate map to real GPS position
        _mapController.move(loc, 15.0);
      }
    } catch (_) {
      // GPS not available — use default center
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar and profile
                      _buildSearchBar(),

                      const SizedBox(height: 16),

                      // Quick destination chips
                      _buildQuickDestinations(),

                      const SizedBox(height: 24),

                      // Live Map section
                      _buildMapSection(),

                      const SizedBox(height: 24),

                      // Ride options section
                      _buildRideOptionsSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom action section
            _buildBottomSection(),

            // Bottom navigation
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LocationSearchScreen(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: kMuted),
                  const SizedBox(width: 12),
                  Text(
                    'Where to?',
                    style: TextStyle(color: kMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Profile avatar - taps navigate to user profile
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserProfileScreen()),
          ),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: kPrimary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Icon(Icons.person, color: kPrimary, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDestinations() {
    return Row(
      children: _quickDestinations.map((dest) {
        final isSelected = _selectedQuickDestination == dest;
        IconData icon;
        switch (dest) {
          case 'Campus':
            icon = Icons.school;
            break;
          case 'Home':
            icon = Icons.home;
            break;
          case 'Library':
            icon = Icons.local_library;
            break;
          default:
            icon = Icons.place;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedQuickDestination = dest),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? kPrimary.withValues(alpha: 0.1)
                    : kBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? kPrimary : kCardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: isSelected ? kPrimary : kMuted),
                  const SizedBox(width: 6),
                  Text(
                    dest,
                    style: TextStyle(
                      color: isSelected ? kPrimary : kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMapSection() {
    final center = _currentLocation ?? _defaultCenter;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Live OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uniride.carpool',
              ),
              // User location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Location label overlay
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLocating) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Locating...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.my_location, size: 14, color: kPrimary),
                    const SizedBox(width: 6),
                    Text(
                      _currentLocation != null ? 'Your Location' : 'Bangalore',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: kPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UniPool — Campus Pooling',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Share rides with verified students · Split fares',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ECO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final cardColor = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: AuthButton(
        label: 'Find a UniPool Ride',
        icon: Icons.search,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationSearchScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final cardColor = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.directions_car, 'Rider'),
          _buildNavItem(1, Icons.local_taxi, 'Driver'),
          _buildNavItem(2, Icons.receipt_long, 'Activity'),
          _buildNavItem(3, Icons.settings_outlined, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          // Navigate to Driver Dashboard
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverDashboardScreen(),
            ),
          );
        } else if (index == 2) {
          // Activity history
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ActivityHistoryScreen(),
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        } else {
          setState(() => _selectedNavIndex = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? kPrimary : kMuted, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kPrimary : kMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
