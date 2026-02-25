import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../../services/location_service.dart';
import 'ride_directions_screen.dart';
import 'pin_drop_screen.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _fromController = TextEditingController();
  String? _selectedCampus;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  LatLng? _fromLatLng;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  // Debounce timer for search
  Timer? _debounce;

  // Christ University Campus locations with real coordinates
  static const List<Map<String, dynamic>> campuses = [
    {
      'name': 'Christ University - Central Campus',
      'address': 'Hosur Road, Bangalore',
      'lat': 12.9347,
      'lng': 77.6066,
    },
    {
      'name': 'Christ University - Kengeri Campus',
      'address': 'Kengeri, Bangalore',
      'lat': 12.9137,
      'lng': 77.4829,
    },
    {
      'name': 'Christ University - Yeshwantpur Campus',
      'address': 'Yeshwantpur, Bangalore',
      'lat': 13.0230,
      'lng': 77.5440,
    },
    {
      'name': 'Christ University - Bannerghatta Campus',
      'address': 'Bannerghatta Road, Bangalore',
      'lat': 12.8698,
      'lng': 77.5950,
    },
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _fromController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _showSearchResults = false;
    });

    try {
      final location = await LocationService.getCurrentLocation();

      // Detect emulator / non-India location
      if (!LocationService.isInIndia(location)) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          _showSnackBar(
            'GPS returned a location outside India. '
            'If using an emulator, set location via Extended Controls (⋯ > Location).',
            Colors.orange,
          );
        }
        return;
      }

      final address = await LocationService.reverseGeocode(location);

      if (mounted) {
        setState(() {
          _fromLatLng = location;
          _fromController.text = address;
          _isLoadingLocation = false;
        });
      }
    } on LocationException catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackBar(e.message, Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackBar(
          'Failed to get location. Try typing your address instead.',
          Colors.orange,
        );
      }
    }
  }

  Future<void> _useSavedAddress() async {
    setState(() => _showSearchResults = false);

    final saved = await LocationService.getSavedPickupAddress();

    if (saved != null) {
      setState(() {
        _fromController.text = saved['address'] as String;
        _fromLatLng = LatLng(
          (saved['lat'] as num).toDouble(),
          (saved['lng'] as num).toDouble(),
        );
      });
    } else {
      if (mounted) {
        _showSnackBar(
          'No saved address found. Set a pickup location and save it!',
          Colors.orange,
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    // Clear coordinates when user is typing a new address
    if (_fromLatLng != null) {
      setState(() => _fromLatLng = null);
    }

    // Cancel previous debounce timer
    _debounce?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    // Show "searching" indicator immediately
    setState(() => _isSearching = true);

    // Wait 600ms after user stops typing before firing request
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _searchAddress(query);
    });
  }

  Future<void> _searchAddress(String query) async {
    final results = await LocationService.forwardGeocode(query.trim());

    if (mounted) {
      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        _isSearching = false;
      });

      if (results.isEmpty) {
        // Don't show snackbar for very short queries
        if (query.trim().length >= 3) {
          _showSnackBar(
            'No results found. Try a more specific address.',
            Colors.orange,
          );
        }
      }
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    setState(() {
      _fromController.text = result['displayName'] as String;
      _fromLatLng = LatLng(
        (result['lat'] as num).toDouble(),
        (result['lng'] as num).toDouble(),
      );
      _showSearchResults = false;
      _searchResults = [];
    });
  }

  Future<void> _saveCurrentAddress() async {
    if (_fromLatLng == null || _fromController.text.isEmpty) {
      _showSnackBar('Set a pickup location first', Colors.orange);
      return;
    }

    await LocationService.savePickupAddress(
      address: _fromController.text,
      lat: _fromLatLng!.latitude,
      lng: _fromLatLng!.longitude,
    );

    if (mounted) {
      _showSnackBar('Address saved!', kPrimary);
    }
  }

  Future<void> _openPinDrop() async {
    setState(() => _showSearchResults = false);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PinDropScreen(initialLocation: _fromLatLng),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _fromLatLng = LatLng(
          (result['lat'] as num).toDouble(),
          (result['lng'] as num).toDouble(),
        );
        _fromController.text = result['address'] as String;
      });
    }
  }

  void _confirmSelection() {
    if (_fromController.text.isEmpty || _selectedCampus == null) {
      _showSnackBar('Please select both pickup and destination', Colors.orange);
      return;
    }

    if (_fromLatLng == null) {
      _showSnackBar(
        'Please search for your address or use Current Location',
        Colors.orange,
      );
      return;
    }

    // Get selected campus coordinates
    final campus = campuses.firstWhere((c) => c['name'] == _selectedCampus);
    final toLatLng = LatLng(
      (campus['lat'] as num).toDouble(),
      (campus['lng'] as num).toDouble(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideDirectionsScreen(
          fromLocation: _fromController.text,
          toLocation: _selectedCampus!,
          fromLatLng: _fromLatLng!,
          toLatLng: toLatLng,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard and search results when tapping outside
          FocusScope.of(context).unfocus();
          setState(() => _showSearchResults = false);
        },
        child: SingleChildScrollView(
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

              // From TextField — editable with debounced search
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _fromLatLng != null ? kPrimary : kCardBorder,
                  ),
                ),
                child: TextField(
                  controller: _fromController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search for an address...',
                    hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.6)),
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: kPrimary,
                    ),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kPrimary,
                              ),
                            ),
                          )
                        : _fromLatLng != null
                        ? const Icon(
                            Icons.check_circle,
                            color: kPrimary,
                            size: 20,
                          )
                        : _fromController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: kMuted, size: 20),
                            onPressed: () {
                              _debounce?.cancel();
                              setState(() {
                                _fromController.clear();
                                _fromLatLng = null;
                                _searchResults = [];
                                _showSearchResults = false;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),

              // Search results dropdown
              if (_showSearchResults) _buildSearchResults(cardColor),

              const SizedBox(height: 12),

              // Quick options — 3 buttons in a row
              Row(
                children: [
                  Expanded(
                    child: _buildQuickOption(
                      icon: Icons.my_location,
                      label: 'Current',
                      isLoading: _isLoadingLocation,
                      onTap: _useCurrentLocation,
                      cardColor: cardColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickOption(
                      icon: Icons.pin_drop,
                      label: 'Pin Map',
                      onTap: _openPinDrop,
                      cardColor: cardColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickOption(
                      icon: Icons.bookmark_outline,
                      label: 'Saved',
                      onTap: _useSavedAddress,
                      cardColor: cardColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickOption(
                      icon: Icons.save_outlined,
                      label: 'Save',
                      onTap: _saveCurrentAddress,
                      cardColor: cardColor,
                      isActive: _fromLatLng != null,
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
                                  ? kPrimary.withValues(alpha: 0.1)
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
      ),
    );
  }

  Widget _buildSearchResults(Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: kCardBorder),
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return ListTile(
            dense: true,
            leading: Icon(Icons.place, color: kPrimary, size: 20),
            title: Text(
              result['displayName'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            onTap: () => _selectSearchResult(result),
          );
        },
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color cardColor,
    bool isLoading = false,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: !isActive ? cardColor.withValues(alpha: 0.5) : cardColor,
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
              Icon(icon, color: isActive ? kPrimary : kMuted, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? null : kMuted,
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
