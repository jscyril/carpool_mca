import 'package:flutter/material.dart';
import '../profile/user_profile.dart';
import '../activity/ride_details_screen.dart';
import '../activity/ride_history_screen.dart';
import 'preferences_screen.dart';
import '../../main.dart';
import '../auth/login.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Profile data loaded from API
  String name = '';
  String contactNumber = '';
  String orgEmail = '';
  String userId = '';
  double? averageRating;
  int totalRatings = 0;
  bool _isLoadingProfile = true;

  // --- TOGGLE STATE ---
  bool isRiderMode = true; // true = Rider, false = Driver

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Fetch user profile
    final profileRes = await UserApiService.getMyProfile();
    if (profileRes.success && profileRes.data != null && mounted) {
      final data = profileRes.data!;
      final uid = data['user_id'] as String? ?? '';
      setState(() {
        name = data['full_name'] ?? '';
        contactNumber = data['phone'] ?? '';
        orgEmail = data['email'] ?? '';
        userId = uid;
      });
      // Fetch rating summary
      if (uid.isNotEmpty) {
        final ratingRes = await RatingApiService.getUserRatingSummary(uid);
        if (ratingRes.success && ratingRes.data != null && mounted) {
          setState(() {
            averageRating = (ratingRes.data!['average_rating'] as num?)
                ?.toDouble();
            totalRatings =
                (ratingRes.data!['total_ratings'] as num?)?.toInt() ?? 0;
          });
        }
      }
    }
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    // Define colors used in the design
    final Color primaryGreen = const Color(0xFF10B981);
    final Color bgGrey = const Color(0xFFF3F4F6);
    final Color textDark = const Color(0xFF1F2937);
    final Color textGrey = const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Profile Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
                    child: _isLoadingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        _isLoadingProfile
                            ? Container(
                                height: 16,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )
                            : Text(
                                name.isNotEmpty ? name : 'Loading...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.school, size: 14, color: primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Verified Student',
                              style: TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Rating row
                        if (!_isLoadingProfile)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                averageRating != null
                                    ? averageRating!.toStringAsFixed(1)
                                    : 'No ratings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                  fontSize: 13,
                                ),
                              ),
                              if (totalRatings > 0)
                                Text(
                                  ' ($totalRatings ${totalRatings == 1 ? 'ride' : 'rides'})',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // --- EDIT BUTTON ---
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            initialData: {
                              'name': name,
                              'contact': contactNumber,
                              'orgEmail': orgEmail,
                              'personalEmail': '',
                            },
                          ),
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          name = result['name'] ?? name;
                          contactNumber = result['contact'] ?? contactNumber;
                          orgEmail = result['orgEmail'] ?? orgEmail;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, color: textGrey),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- FUNCTIONAL MODE TOGGLE ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // RIDER BUTTON
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isRiderMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isRiderMode
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isRiderMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Rider Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isRiderMode ? primaryGreen : textGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // DRIVER BUTTON
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isRiderMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isRiderMode
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !isRiderMode
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Driver Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !isRiderMode ? primaryGreen : textGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ACTIVITY SECTION ---
            _buildSectionHeader('ACTIVITY'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // --- CLICKABLE RIDE ENTRY ---
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RideDetailsScreen(
                            destination: 'Central Library',
                            source: 'North Campus Dorms',
                            time: 'Today, 9:00 AM',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.history, color: primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Today, 9:00 AM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textGrey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Central Library',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'from ',
                                      style: TextStyle(color: textGrey),
                                    ),
                                    TextSpan(
                                      text: 'North Campus Dorms',
                                      style: TextStyle(
                                        color: textDark,
                                        fontWeight: FontWeight.w500,
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
                  ),

                  // ---------------------------
                  const Divider(height: 1),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RideHistoryScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'View full history',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: textDark,
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 18, color: textDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- CONFIGURATION SECTION ---
            _buildSectionHeader('CONFIGURATION'),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PreferencesScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: _buildConfigCard(
                      icon: Icons.tune,
                      color: Colors.blue,
                      title: 'Preferences',
                      subtitle: 'Notifications, Saved Places',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildConfigCard(
                    icon: Icons.credit_card,
                    color: Colors.green,
                    title: 'Payment',
                    subtitle: 'Cards, Wallets',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- SAFETY ZONE SECTION ---
            Row(
              children: [
                Icon(Icons.security, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'SAFETY ZONE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.orange,
                    iconBg: Colors.orange.withOpacity(0.1),
                    title: 'Report User or Driver',
                    subtitle: 'Flag inappropriate behavior',
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    icon: Icons.sos,
                    iconColor: Colors.red,
                    iconBg: Colors.red.withOpacity(0.1),
                    title: 'Safety Center',
                    subtitle: 'Emergency contacts & SOS',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- SUPPORT SECTION ---
            _buildSectionHeader('SUPPORT'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.confirmation_number_outlined,
                    iconColor: textGrey,
                    title: 'Raise a Ticket',
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    icon: Icons.bug_report_outlined,
                    iconColor: textGrey,
                    title: 'Report a Bug',
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildListTile(
                    icon: Icons.help_outline,
                    iconColor: textGrey,
                    title: 'Help & FAQ',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- Footer ---
            Center(
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx); // close dialog
                            await AuthService.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Version 2.1.0 • Build 8492',
                style: TextStyle(color: textGrey, fontSize: 12),
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
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF6B7280),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildConfigCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    Color? iconBg,
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg ?? Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
