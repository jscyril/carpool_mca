import 'package:flutter/material.dart';

class RideDetailsScreen extends StatelessWidget {
  final String destination;
  final String source;
  final String time;
  final String price;

  const RideDetailsScreen({
    super.key,
    // Customized defaults for Indian context
    this.destination = 'MG Road Metro Station',
    this.source = 'Indiranagar 12th Main',
    this.time = 'Today, 9:00 AM',
    this.price = '₹145.50',
  });

  @override
  Widget build(BuildContext context) {
    // Define colors
    final Color primaryGreen = const Color(0xFF10B981);
    final Color textDark = const Color(0xFF1F2937);
    final Color textGrey = const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ride Details',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Map Placeholder ---
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[200],
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Map View',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  // Fake Route Line Visual
                  Positioned(
                    top: 80,
                    left: 60,
                    right: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          color: primaryGreen,
                          size: 20,
                        ),
                        Expanded(
                          child: Divider(color: primaryGreen, thickness: 2),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 2. Date & Status ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: TextStyle(color: textGrey, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- 3. Vehicle & Driver ---
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: const NetworkImage(
                          'https://i.pravatar.cc/150?img=60',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suzuki Dzire', // Common Indian Cab
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'Ramesh • KA 05 MB 8492', // Indian format Plate Number
                            style: TextStyle(color: textGrey, fontSize: 13),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price, // Indian Rupee Symbol
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'UPI - PhonePe', // Popular Payment Method
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 40),

                  // --- 4. Trip Timeline ---
                  _buildLocationRow(
                    time: '9:00 AM',
                    location: source,
                    icon: Icons.radio_button_checked,
                    iconColor: primaryGreen,
                    isFirst: true,
                  ),
                  _buildLocationRow(
                    time: '9:45 AM', // Adjusted typical traffic time gap
                    location: destination,
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    isLast: true,
                  ),

                  const Divider(height: 40),

                  // --- 5. Ratings ---
                  Center(
                    child: Column(
                      children: [
                        Text('You rated', style: TextStyle(color: textGrey)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- 6. Help Button ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Get Help with this Ride'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required String time,
    required String location,
    required IconData icon,
    required Color iconColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // Visual Line Column
          Column(
            children: [
              Icon(icon, size: 16, color: iconColor),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Location Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
