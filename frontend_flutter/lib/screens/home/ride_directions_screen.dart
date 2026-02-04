import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';

class RideDirectionsScreen extends StatelessWidget {
  final String fromLocation;
  final String toLocation;

  const RideDirectionsScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
  });

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
          'Route Preview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Location summary card
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                  label: 'From',
                  location: fromLocation,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(width: 2, height: 30, color: kCardBorder),
                ),
                _buildLocationRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'To',
                  location: toLocation,
                ),
              ],
            ),
          ),

          // Simulated Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE8F5E9),
                    const Color(0xFFC8E6C9),
                    kPrimary.withOpacity(0.2),
                  ],
                ),
                border: Border.all(color: kCardBorder),
              ),
              child: Stack(
                children: [
                  // Simulated route line
                  Center(
                    child: CustomPaint(
                      size: const Size(200, 150),
                      painter: _RoutePainter(),
                    ),
                  ),

                  // From marker
                  Positioned(
                    top: 40,
                    left: 50,
                    child: _buildMapMarker(
                      icon: Icons.circle,
                      color: kPrimary,
                      label: 'Start',
                    ),
                  ),

                  // To marker
                  Positioned(
                    bottom: 60,
                    right: 50,
                    child: _buildMapMarker(
                      icon: Icons.location_on,
                      color: Colors.red,
                      label: 'End',
                    ),
                  ),

                  // Map placeholder text
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, size: 48, color: kPrimary),
                        SizedBox(height: 8),
                        Text(
                          'Map Preview',
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Route visualization coming soon',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: kCardBorder)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated fare',
                      style: TextStyle(color: kMuted),
                    ),
                    const Text(
                      '₹80 - ₹150',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AuthButton(
                  label: 'Request Ride',
                  icon: Icons.directions_car,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Looking for available rides...'),
                        backgroundColor: kPrimary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    // Pop back to home after a delay
                    Future.delayed(const Duration(seconds: 1), () {
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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

  Widget _buildMapMarker({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for simulated route
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.5,
        size.width * 0.5,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.3,
        size.width,
        size.height,
      );

    // Draw dashed line
    final dashPath = Path();
    const dashLength = 8.0;
    const gapLength = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashLength).clamp(0, metric.length);
        dashPath.addPath(
          metric.extractPath(start, end.toDouble()),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
