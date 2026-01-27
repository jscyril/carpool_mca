import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  String _selectedQuickDestination = 'Campus';

  final List<String> _quickDestinations = ['Campus', 'Home', 'Library'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

                      // Map placeholder
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
        const SizedBox(width: 12),
        // Profile avatar
        Container(
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
          child: ClipOval(child: Icon(Icons.person, color: kPrimary, size: 28)),
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
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
      ),
      child: Stack(
        children: [
          // Simulated map background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                  ),
                ),
              ),
            ),
          ),
          // Location label
          Positioned(
            left: 16,
            top: 16,
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
              child: const Text(
                'Student Union',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          // Location pin
          Positioned(
            left: 50,
            top: 70,
            child: Icon(Icons.location_on, color: kPrimary, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildRideOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Choose a ride',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              'Sorted by price',
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // UniPool option (Eco Choice)
        _buildRideOption(
          title: 'UniPool',
          subtitle: '3 seats left • 4 min away',
          price: '\$4.50',
          originalPrice: '\$6.00',
          isEcoChoice: true,
          isSelected: true,
        ),

        const SizedBox(height: 12),

        // Direct option
        _buildRideOption(
          title: 'Direct',
          subtitle: 'Private • 6 min away',
          price: '\$8.00',
          isEcoChoice: false,
          isSelected: false,
        ),
      ],
    );
  }

  Widget _buildRideOption({
    required String title,
    required String subtitle,
    required String price,
    String? originalPrice,
    required bool isEcoChoice,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? kPrimary : kCardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEcoChoice
                  ? kPrimary.withValues(alpha: 0.1)
                  : kBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEcoChoice ? Icons.people : Icons.directions_car,
              color: isEcoChoice ? kPrimary : kMuted,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (isEcoChoice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ECO CHOICE',
                          style: TextStyle(
                            color: kPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: kMuted, fontSize: 13)),
              ],
            ),
          ),

          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (originalPrice != null)
                Text(
                  originalPrice,
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: Column(
        children: [
          // Payment method
          Row(
            children: [
              Icon(Icons.credit_card, color: kMuted, size: 20),
              const SizedBox(width: 8),
              Text(
                'Visa •••• 4242',
                style: TextStyle(color: kMuted, fontWeight: FontWeight.w500),
              ),
              Icon(Icons.keyboard_arrow_down, color: kMuted, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code, color: kMuted, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Request button
          AuthButton(
            label: 'Request UniPool',
            icon: Icons.arrow_forward,
            onPressed: () {
              // TODO: Request ride
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Looking for drivers...'),
                  backgroundColor: kPrimary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.directions_car, 'Rider'),
          _buildNavItem(1, Icons.local_taxi, 'Driver'),
          _buildNavItem(2, Icons.receipt_long, 'Activity'),
          _buildNavItem(3, Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = index),
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
