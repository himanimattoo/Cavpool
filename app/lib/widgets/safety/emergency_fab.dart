import 'package:flutter/material.dart';
import 'emergency_button.dart';

class EmergencyFAB extends StatelessWidget {
  final String? rideId;
  final bool mini;

  const EmergencyFAB({
    super.key,
    this.rideId,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showEmergencyDialog(context),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      heroTag: 'emergency_fab',
      mini: mini,
      child: const Icon(Icons.emergency),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: EmergencyButton(
          rideId: rideId,
          showConfirmDialog: false,
          width: double.infinity,
        ),
      ),
    );
  }
}