import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';
import '../../main.dart';
import 'ride_directions_screen.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _fromController = TextEditingController();
  String? _selectedCampus;
  bool _isLoadingLocation = false;

  // Christ University Campus locations
  static const List<Map<String, String>> campuses = [
    {
      'name': 'Christ University - Central Campus',
      'address': 'Hosur Road, Bangalore',
    },
    {
      'name': 'Christ University - Kengeri Campus',
      'address': 'Kengeri, Bangalore',
    },
    {
      'name': 'Christ University - Yeshwantpur Campus',
      'address': 'Yeshwantpur, Bangalore',
    },
    {
      'name': 'Christ University - Bannerghatta Campus',
      'address': 'Bannerghatta Road, Bangalore',
    },
  ];

  @override
  void dispose() {
    _fromController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    // Simulate getting location
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _fromController.text = 'Current Location (Detected)';
      _isLoadingLocation = false;
    });
  }

  Future<void> _useSavedAddress() async {
    final profile = await AuthService.getUserProfile();
    final address = profile['address'];

    if (address != null && address.isNotEmpty) {
      setState(() {
        _fromController.text = address;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No saved address found'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _confirmSelection() {
    if (_fromController.text.isEmpty || _selectedCampus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both pickup and destination'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDirectionsScreen(
          fromLocation: _fromController.text,
          toLocation: _selectedCampus!,
        ),
      ),
    );
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
          'Choose Route',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From Section
            const Text(
              'PICKUP LOCATION',
              style: TextStyle(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: kMuted,
              ),
            ),
            const SizedBox(height: 10),

            // From TextField
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCardBorder),
              ),
              child: TextField(
                controller: _fromController,
                decoration: InputDecoration(
                  hintText: 'Enter pickup address',
                  hintStyle: TextStyle(color: kMuted.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.location_on_outlined, color: kPrimary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick options
            Row(
              children: [
                Expanded(
                  child: _buildQuickOption(
                    icon: Icons.my_location,
                    label: 'Current Location',
                    isLoading: _isLoadingLocation,
                    onTap: _useCurrentLocation,
                    cardColor: cardColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickOption(
                    icon: Icons.home_outlined,
                    label: 'Saved Address',
                    onTap: _useSavedAddress,
                    cardColor: cardColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // To Section
            const Text(
              'DESTINATION',
              style: TextStyle(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: kMuted,
              ),
            ),
            const SizedBox(height: 10),

            // Campus list
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCardBorder),
              ),
              child: Column(
                children: campuses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final campus = entry.value;
                  final isSelected = _selectedCampus == campus['name'];
                  final isLast = index == campuses.length - 1;

                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kPrimary.withOpacity(0.1)
                                : kBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.school,
                            color: isSelected ? kPrimary : kMuted,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          campus['name']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kPrimary : null,
                          ),
                        ),
                        subtitle: Text(
                          campus['address']!,
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: kPrimary)
                            : null,
                        onTap: () {
                          setState(() => _selectedCampus = campus['name']);
                        },
                      ),
                      if (!isLast) Divider(height: 1, color: kCardBorder),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // Confirm button
            AuthButton(
              label: 'Find Rides',
              icon: Icons.search,
              onPressed: _confirmSelection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color cardColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimary,
                ),
              )
            else
              Icon(icon, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
