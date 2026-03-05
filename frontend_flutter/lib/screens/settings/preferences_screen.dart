import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../main.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Toggle states
  bool isDarkMode = false;
  bool pushNotifications = false;
  bool emailUpdates = false;
  bool locationSharing = false; // Start false until we verify GPS & permissions

  // --- DYNAMIC DATA FOR LOCATIONS ---
  List<Map<String, dynamic>> savedLocations = [
    {
      'title': 'Home',
      'subtitle': '123 University Ave, Block A',
      'icon': Icons.home,
    },
    {
      'title': 'Campus',
      'subtitle': 'Main Square Gate 4, Sector 62',
      'icon': Icons.school,
    },
  ];

  // Colors matching settings_screen
  final Color primaryGreen = const Color(0xFF10B981);
  final Color bgGrey = const Color(0xFFF3F4F6);
  final Color textDark = const Color(0xFF1F2937);
  final Color textGrey = const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    isDarkMode = themeNotifier.isDarkMode;
    _checkInitialPermissions();
  }

  // Check BOTH permissions when the screen loads
  Future<void> _checkInitialPermissions() async {
    final notifStatus = await Permission.notification.status;

    // For location to be "true", we need permission AND the GPS hardware must be on
    final locStatus = await Permission.locationWhenInUse.status;
    final isGpsOn = await Permission.location.serviceStatus.isEnabled;

    setState(() {
      pushNotifications = notifStatus.isGranted;
      locationSharing = locStatus.isGranted && isGpsOn;
    });
  }

  // Handle Push Notifications Toggle
  Future<void> _handleNotificationToggle(bool requestedState) async {
    if (requestedState == true) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() => pushNotifications = true);
      } else if (status.isPermanentlyDenied) {
        setState(() => pushNotifications = false);
        _showSettingsSnackBar('Notifications');
      } else {
        setState(() => pushNotifications = false);
      }
    } else {
      setState(() => pushNotifications = false);
    }
  }

  // Handle Location Sharing Toggle
  Future<void> _handleLocationToggle(bool requestedState) async {
    if (requestedState == true) {
      // 1. Check if the physical GPS is turned on first!
      bool isGpsOn = await Permission.location.serviceStatus.isEnabled;
      if (!isGpsOn) {
        setState(() => locationSharing = false);
        _showSimpleSnackBar(
          'Location services are disabled. Please turn on your device GPS.',
        );
        return; // Stop here, don't ask for permission if GPS is off
      }

      // 2. If GPS is on, request the app permission
      final status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        setState(() => locationSharing = true);
      } else if (status.isPermanentlyDenied) {
        setState(() => locationSharing = false);
        _showSettingsSnackBar('Location');
      } else {
        setState(() => locationSharing = false);
      }
    } else {
      setState(() => locationSharing = false);
    }
  }

  // Reusable snackbar for permanently denied permissions
  void _showSettingsSnackBar(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName are blocked in device settings.'),
        action: SnackBarAction(
          label: 'OPEN SETTINGS',
          textColor: primaryGreen,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  // Reusable simple snackbar
  void _showSimpleSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- BLINKIT-STYLE BOTTOM SHEET ---
  void _showAddressBottomSheet({int? index}) {
    final isEditing = index != null;

    // Parse existing data if editing
    String initialTitle = isEditing ? savedLocations[index]['title'] : 'Home';
    String initialSubtitle = isEditing ? savedLocations[index]['subtitle'] : '';

    // Attempt to split the subtitle back into flat and area
    List<String> addressParts = initialSubtitle.split(', ');
    String initialFlat = addressParts.isNotEmpty ? addressParts[0] : '';
    String initialArea = addressParts.length > 1 ? addressParts[1] : '';

    // Figure out initial tag
    String activeTag = ['Home', 'Work'].contains(initialTitle)
        ? initialTitle
        : 'Other';

    final flatController = TextEditingController(text: initialFlat);
    final areaController = TextEditingController(text: initialArea);
    final customTagController = TextEditingController(
      text: activeTag == 'Other' ? initialTitle : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Update Address'
                              : 'Enter complete address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textDark),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),

                    TextField(
                      controller: flatController,
                      decoration: InputDecoration(
                        labelText: 'Flat / House no / Floor / Building *',
                        labelStyle: TextStyle(color: textGrey, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryGreen),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: areaController,
                      decoration: InputDecoration(
                        labelText: 'Area / Sector / Locality *',
                        labelStyle: TextStyle(color: textGrey, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryGreen),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Save address as',
                      style: TextStyle(
                        fontSize: 14,
                        color: textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTagChip('Home', Icons.home, activeTag, (tag) {
                          setModalState(() => activeTag = tag);
                        }),
                        const SizedBox(width: 12),
                        _buildTagChip('Work', Icons.work, activeTag, (tag) {
                          setModalState(() => activeTag = tag);
                        }),
                        const SizedBox(width: 12),
                        _buildTagChip('Other', Icons.location_on, activeTag, (
                          tag,
                        ) {
                          setModalState(() => activeTag = tag);
                        }),
                      ],
                    ),

                    if (activeTag == 'Other') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: customTagController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Gym, Girlfriend\'s House',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryGreen),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  savedLocations.removeAt(index);
                                });
                                Navigator.pop(context);
                              },
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (flatController.text.isNotEmpty &&
                                  areaController.text.isNotEmpty) {
                                String finalTitle = activeTag == 'Other'
                                    ? (customTagController.text.isEmpty
                                          ? 'Other'
                                          : customTagController.text)
                                    : activeTag;

                                IconData finalIcon = activeTag == 'Home'
                                    ? Icons.home
                                    : (activeTag == 'Work'
                                          ? Icons.work
                                          : Icons.location_on);

                                setState(() {
                                  final newLocation = {
                                    'title': finalTitle,
                                    'subtitle':
                                        '${flatController.text}, ${areaController.text}',
                                    'icon': finalIcon,
                                  };

                                  if (isEditing) {
                                    savedLocations[index] = newLocation;
                                  } else {
                                    savedLocations.add(newLocation);
                                  }
                                });
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              'Save Address',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTagChip(
    String label,
    IconData icon,
    String activeTag,
    Function(String) onTap,
  ) {
    bool isSelected = activeTag == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey[300]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? primaryGreen : textGrey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryGreen : textGrey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Preferences',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- APPEARANCE ---
            _buildSectionHeader('APPEARANCE'),
            _buildContainer(
              child: _buildSwitchTile(
                icon: Icons.nightlight_round,
                title: 'Dark Mode',
                subtitle: 'Reduce glare and save battery',
                value: isDarkMode,
                onChanged: (val) {
                  setState(() => isDarkMode = val);
                  themeNotifier.setDarkMode(val);
                },
              ),
            ),
            const SizedBox(height: 24),

            // --- NOTIFICATIONS ---
            _buildSectionHeader('NOTIFICATIONS'),
            _buildContainer(
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications,
                    title: 'Push Notifications',
                    value: pushNotifications,
                    onChanged: (val) => _handleNotificationToggle(val),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSwitchTile(
                    icon: Icons.email,
                    title: 'Email Updates',
                    value: emailUpdates,
                    onChanged: (val) => setState(() => emailUpdates = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- SAVED LOCATIONS ---
            _buildSectionHeader('SAVED LOCATIONS'),
            _buildContainer(
              child: Column(
                children: [
                  ...savedLocations.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> location = entry.value;
                    return Column(
                      children: [
                        _buildLocationTile(
                          icon: location['icon'],
                          title: location['title'],
                          subtitle: location['subtitle'],
                          onTap: () => _showAddressBottomSheet(index: index),
                        ),
                        const Divider(height: 1, indent: 60),
                      ],
                    );
                  }).toList(),

                  InkWell(
                    onTap: () => _showAddressBottomSheet(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle, color: primaryGreen, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Add another location',
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- PRIVACY ---
            _buildSectionHeader('PRIVACY'),
            _buildContainer(
              child: _buildSwitchTile(
                icon: Icons.location_on,
                title: 'Location Sharing',
                subtitle:
                    'Allow fellow carpoolers to see your real-time pickup spot for 15 minutes before your scheduled ride.',
                value: locationSharing,
                // UPDATED TO USE OUR NEW LOCATION HANDLER
                onChanged: (val) => _handleLocationToggle(val),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: textGrey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textDark,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: primaryGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
