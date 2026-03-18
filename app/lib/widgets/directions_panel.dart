import 'package:flutter/material.dart';
import '../services/directions_service.dart';

class DirectionsPanel extends StatelessWidget {
  final List<DirectionStep> steps;
  final VoidCallback? onClose;

  const DirectionsPanel({
    super.key,
    required this.steps,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions, color: Color(0xFFE57200)),
                const SizedBox(width: 8),
                const Text(
                  'Turn-by-Turn Directions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    iconSize: 20,
                  ),
              ],
            ),
          ),
          
          // Directions List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                return DirectionStepTile(
                  step: step,
                  stepNumber: index + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DirectionStepTile extends StatelessWidget {
  final DirectionStep step;
  final int stepNumber;

  const DirectionStepTile({
    super.key,
    required this.step,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number and maneuver icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE57200),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: _getManeuverIcon(step.maneuver),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Direction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruction text
                Text(
                  _cleanInstructions(step.instruction),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Distance and duration
                Row(
                  children: [
                    if (step.distance.isNotEmpty) ...[
                      Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        step.distance,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (step.distance.isNotEmpty && step.duration.isNotEmpty)
                      const SizedBox(width: 16),
                    if (step.duration.isNotEmpty) ...[
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        step.duration,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getManeuverIcon(String maneuver) {
    IconData iconData;
    
    switch (maneuver.toLowerCase()) {
      case 'turn-left':
        iconData = Icons.turn_left;
        break;
      case 'turn-right':
        iconData = Icons.turn_right;
        break;
      case 'turn-slight-left':
        iconData = Icons.turn_slight_left;
        break;
      case 'turn-slight-right':
        iconData = Icons.turn_slight_right;
        break;
      case 'turn-sharp-left':
        iconData = Icons.turn_sharp_left;
        break;
      case 'turn-sharp-right':
        iconData = Icons.turn_sharp_right;
        break;
      case 'straight':
        iconData = Icons.straight;
        break;
      case 'ramp-left':
      case 'fork-left':
        iconData = Icons.fork_left;
        break;
      case 'ramp-right':
      case 'fork-right':
        iconData = Icons.fork_right;
        break;
      case 'merge':
        iconData = Icons.merge;
        break;
      case 'roundabout-left':
      case 'roundabout-right':
        iconData = Icons.roundabout_left;
        break;
      case 'uturn-left':
      case 'uturn-right':
        iconData = Icons.u_turn_left;
        break;
      default:
        iconData = Icons.navigation;
    }
    
    return Icon(
      iconData,
      color: Colors.white,
      size: 20,
    );
  }

  String _cleanInstructions(String htmlInstructions) {
    // Remove HTML tags and decode common entities
    return htmlInstructions
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}