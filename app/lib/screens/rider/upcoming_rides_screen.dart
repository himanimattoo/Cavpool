import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../requests/ride_request_screen.dart';

class UpcomingRidesScreen extends StatelessWidget {
  const UpcomingRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

        // Bottom Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RideRequestScreen(),
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
                    Icons.search,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Where to?',
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
        ),
      ],
    );
  }
}