import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/passenger_provider.dart';
import '../../models/ride_model.dart';

class RideProgressIndicator extends StatelessWidget {
  final PassengerRideState currentState;
  final PickupStatus pickupStatus;

  const RideProgressIndicator({
    super.key,
    required this.currentState,
    required this.pickupStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride Progress',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 16),
        
        _buildProgressSteps(),
      ],
    );
  }

  Widget _buildProgressSteps() {
    final steps = _getProgressSteps();
    
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: step.isCompleted 
                        ? Colors.green[600] 
                        : step.isActive 
                            ? Colors.blue[600] 
                            : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.isCompleted 
                        ? Icons.check 
                        : step.isActive 
                            ? Icons.circle 
                            : Icons.circle_outlined,
                    size: 14,
                    color: step.isCompleted || step.isActive 
                        ? Colors.white 
                        : Colors.grey[600],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: step.isCompleted 
                        ? Colors.green[600] 
                        : Colors.grey[300],
                  ),
              ],
            ),
            
            const SizedBox(width: 16),
            
            // Step content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: step.isActive 
                          ? Colors.blue[600] 
                          : step.isCompleted 
                              ? Colors.green[600] 
                              : Colors.grey[600],
                    ),
                  ),
                  if (step.subtitle != null)
                    Text(
                      step.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (step.isActive && step.estimatedTime != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ETA: ${step.estimatedTime}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  List<ProgressStep> _getProgressSteps() {
    return [
      ProgressStep(
        title: 'Request Sent',
        subtitle: 'Looking for available drivers',
        isCompleted: currentState != PassengerRideState.requestPending,
        isActive: currentState == PassengerRideState.requestPending,
      ),
      ProgressStep(
        title: 'Driver Found',
        subtitle: 'Driver accepted your request',
        isCompleted: _isStateCompleted(PassengerRideState.matched),
        isActive: currentState == PassengerRideState.matched,
      ),
      ProgressStep(
        title: 'Driver En Route',
        subtitle: 'Driver is coming to pick you up',
        isCompleted: _isStateCompleted(PassengerRideState.driverEnRoute),
        isActive: currentState == PassengerRideState.driverEnRoute,
        estimatedTime: currentState == PassengerRideState.driverEnRoute ? '5 min' : null,
      ),
      ProgressStep(
        title: 'Driver Arrived',
        subtitle: 'Driver is at your pickup location',
        isCompleted: _isStateCompleted(PassengerRideState.driverArrived),
        isActive: currentState == PassengerRideState.driverArrived,
      ),
      ProgressStep(
        title: 'In Ride',
        subtitle: 'Heading to your destination',
        isCompleted: _isStateCompleted(PassengerRideState.inRide),
        isActive: currentState == PassengerRideState.inRide,
        estimatedTime: currentState == PassengerRideState.inRide ? '12 min' : null,
      ),
      ProgressStep(
        title: 'Completed',
        subtitle: 'You\'ve arrived at your destination',
        isCompleted: currentState == PassengerRideState.completed,
        isActive: false,
      ),
    ];
  }

  bool _isStateCompleted(PassengerRideState targetState) {
    final stateOrder = [
      PassengerRideState.requestPending,
      PassengerRideState.matched,
      PassengerRideState.driverEnRoute,
      PassengerRideState.driverArrived,
      PassengerRideState.inRide,
      PassengerRideState.completed,
    ];
    
    final currentIndex = stateOrder.indexOf(currentState);
    final targetIndex = stateOrder.indexOf(targetState);
    
    return currentIndex > targetIndex;
  }
}

class ProgressStep {
  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isActive;
  final String? estimatedTime;

  ProgressStep({
    required this.title,
    this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.estimatedTime,
  });
}