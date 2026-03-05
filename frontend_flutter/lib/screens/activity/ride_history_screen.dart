import 'package:flutter/material.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  // Tab Selection State
  String _selectedTab = 'All';

  @override
  Widget build(BuildContext context) {
    // --- APP THEME CONSTANTS ---
    final Color primaryGreen = const Color(0xFF10B981);
    final Color bgGrey = const Color(0xFFF3F4F6);
    final Color textDark = const Color(0xFF1F2937);
    final Color textGrey = const Color(0xFF6B7280);

    // --- MOCK DATA (Indian Context) ---
    final List<Map<String, dynamic>> historyData = [
      {
        'status': 'COMPLETED',
        'statusColor': primaryGreen,
        'date': 'Oct 24, 02:30 PM',
        'price': '₹145.50',
        'pickup': 'North Campus Library',
        'dropoff': 'Student Union Building',
        'userRole': 'Driver',
        'userName': 'Ramesh Kumar',
        'userImage': 'https://i.pravatar.cc/150?img=11',
        'isRiderView': true, // User was the RIDER
      },
      {
        'status': 'AS DRIVER',
        'statusColor': Colors.blueAccent,
        'date': 'Oct 22, 09:15 AM',
        'price': '₹80.00',
        'pickup': 'Engineering Block B',
        'dropoff': 'West Gate Entrance',
        'userRole': 'Riders',
        'userName': '3 Students',
        'userImage': 'https://i.pravatar.cc/150?img=33',
        'isRiderView': false, // User was the DRIVER
      },
      {
        'status': 'CANCELLED',
        'statusColor': textGrey,
        'date': 'Oct 20, 05:45 PM',
        'price': '₹0.00',
        'pickup': 'Main Stadium',
        'dropoff': 'Dormitory Hall A',
        'userRole': 'Driver',
        'userName': 'Marcus Wright',
        'userImage': 'https://i.pravatar.cc/150?img=12',
        'isRiderView': true, // User was the RIDER
      },
      {
        'status': 'COMPLETED',
        'statusColor': primaryGreen,
        'date': 'Oct 18, 12:00 PM',
        'price': '₹210.75',
        'pickup': 'Medical Center',
        'dropoff': 'South Campus Hub',
        'userRole': 'Driver',
        'userName': 'Sarah Jenkins',
        'userImage': 'https://i.pravatar.cc/150?img=5',
        'isRiderView': true, // User was the RIDER
      },
    ];

    // --- FILTER LOGIC ---
    final List<Map<String, dynamic>> filteredData = historyData.where((ride) {
      if (_selectedTab == 'All') return true;
      if (_selectedTab == 'As Rider') return ride['isRiderView'] == true;
      if (_selectedTab == 'As Driver') return ride['isRiderView'] == false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, size: 18, color: textDark),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ride History',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune, size: 18, color: textDark),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. Custom Tab Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTab('All'),
                  _buildTab('As Rider'),
                  _buildTab('As Driver'),
                ],
              ),
            ),
          ),

          // --- 2. Ride List ---
          Expanded(
            child: filteredData.isEmpty
                ? Center(
                    child: Text(
                      "No rides found",
                      style: TextStyle(color: textGrey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredData.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildRideCard(filteredData[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTab(String title) {
    bool isActive = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF10B981)
                : Colors.transparent, // Active Green
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> data) {
    final bool isCancelled = data['status'] == 'CANCELLED';
    final Color statusColor = data['statusColor'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Status & Price ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data['date'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                data['price'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCancelled
                      ? Colors.grey[400]
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Route Visualizer ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line Graphic
              Column(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  Container(
                    height: 24,
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Icon(Icons.circle, size: 14, color: Color(0xFF10B981)),
                ],
              ),
              const SizedBox(width: 12),
              // Addresses
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['pickup'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isCancelled
                            ? Colors.grey[400]
                            : const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: 14,
                    ), // Spacing to match dotted line height
                    Text(
                      data['dropoff'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isCancelled
                            ? Colors.grey[400]
                            : const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),

          // --- Footer: Driver/Rider Info ---
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(data['userImage']),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['userRole'],
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Text(
                    data['userName'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isCancelled)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
