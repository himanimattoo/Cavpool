import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../requests/ride_request_screen.dart';
import '../requests/requests_list_screen.dart';
import '../rides/rides_list_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _showUpcomingRides = true;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Rider',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF232F3E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: !_showUpcomingRides ? [
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            tooltip: _showArchived ? 'Show Active' : 'Show Archived',
          ),
        ] : null,
      ),
      body: Column(
        children: [

            // Toggle Buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'Upcoming Rides',
                      _showUpcomingRides,
                      () => setState(() => _showUpcomingRides = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      'Ride Requests',
                      !_showUpcomingRides,
                      () => setState(() => _showUpcomingRides = false),
                    ),
                  ),
                ],
              ),
            ),

          // Content based on selected tab
          Expanded(
            child: _showUpcomingRides ? _buildUpcomingRides() : _buildRideRequests(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF232F3E) : Colors.white, // UVA Navy when selected
          border: Border.all(
            color: isSelected ? const Color(0xFF232F3E) : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingRides() {
    return Column(
      children: [
        // Main Content
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Car Icon
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Icon(
                    Icons.directions_car,
                    size: 80,
                    color: const Color(0xFFE57200), // UVA Orange
                  ),
                ),
                const SizedBox(height: 24),

                // Text Messages
                Text(
                  'You have no upcoming rides,',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'WHERE TO?',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF232F3E), // UVA Navy
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RidesListScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57200), // UVA Orange
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_car,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Browse Available Rides',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RideRequestScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE57200)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFFE57200),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Request a Ride',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE57200),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideRequests() {
    return RequestsListScreen(showArchived: _showArchived);
  }
}
