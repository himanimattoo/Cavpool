import 'package:flutter/material.dart';
import '../services/routes_service.dart';

class DistanceChip extends StatelessWidget {
  final double distanceInMeters;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const DistanceChip({
    super.key,
    required this.distanceInMeters,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (distanceInMeters <= 0) {
      return const SizedBox.shrink();
    }

    final routesService = RoutesService();
    final formattedDistance = routesService.formatDistance(distanceInMeters);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route,
            size: fontSize ?? 14,
            color: iconColor ?? Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            formattedDistance,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              color: textColor ?? Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler icon + text variant for inline use
class DistanceText extends StatelessWidget {
  final double distanceInMeters;
  final Color? color;
  final double? fontSize;

  const DistanceText({
    super.key,
    required this.distanceInMeters,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (distanceInMeters <= 0) {
      return const SizedBox.shrink();
    }

    final routesService = RoutesService();
    final formattedDistance = routesService.formatDistance(distanceInMeters);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.route,
          size: fontSize ?? 14,
          color: color ?? Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          formattedDistance,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            color: color ?? Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}