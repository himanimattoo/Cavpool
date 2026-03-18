import '../models/user_model.dart';

class UnitsFormatter {
  static const double _metersToMiles = 0.000621371;
  static const double _metersToFeet = 3.28084;
  static const double _metersToKm = 0.001;

  /// Format distance based on user preferences
  static String formatDistance(double meters, {DistanceUnit? unit}) {
    final effectiveUnit = unit ?? DistanceUnit.imperial; // Default to imperial (feet/miles)
    
    switch (effectiveUnit) {
      case DistanceUnit.imperial:
        return _formatImperialDistance(meters);
      case DistanceUnit.metric:
        return _formatMetricDistance(meters);
    }
  }

  /// Format distance in miles and feet
  static String _formatImperialDistance(double meters) {
    final miles = meters * _metersToMiles;
    
    if (miles >= 1.0) {
      return '${miles.toStringAsFixed(1)} mi';
    } else {
      final feet = (meters * _metersToFeet).round();
      if (feet < 100) {
        return '$feet ft';
      } else {
        // Round to nearest 10 feet for readability
        final roundedFeet = ((feet / 10).round() * 10);
        return '$roundedFeet ft';
      }
    }
  }

  /// Format distance in kilometers and meters
  static String _formatMetricDistance(double meters) {
    if (meters >= 1000) {
      final km = meters * _metersToKm;
      return '${km.toStringAsFixed(1)} km';
    } else {
      final roundedMeters = meters.round();
      if (roundedMeters < 100) {
        return '$roundedMeters m';
      } else {
        // Round to nearest 10 meters for readability
        final rounded = ((roundedMeters / 10).round() * 10);
        return '$rounded m';
      }
    }
  }

  /// Format distance for voice announcements
  static String formatDistanceForVoice(double meters, {DistanceUnit? unit}) {
    final effectiveUnit = unit ?? DistanceUnit.imperial;
    
    switch (effectiveUnit) {
      case DistanceUnit.imperial:
        return _formatImperialDistanceForVoice(meters);
      case DistanceUnit.metric:
        return _formatMetricDistanceForVoice(meters);
    }
  }

  static String _formatImperialDistanceForVoice(double meters) {
    final miles = meters * _metersToMiles;
    
    if (miles >= 1.0) {
      if (miles >= 2.0) {
        return '${miles.toStringAsFixed(0)} miles';
      } else {
        return '${miles.toStringAsFixed(1)} mile';
      }
    } else {
      final feet = (meters * _metersToFeet).round();
      if (feet <= 100) {
        return '$feet feet';
      } else {
        // Round to quarter mile increments for long distances
        final quarterMiles = (miles * 4).round();
        if (quarterMiles == 1) {
          return 'a quarter mile';
        } else if (quarterMiles == 2) {
          return 'half a mile';
        } else if (quarterMiles == 3) {
          return 'three quarters of a mile';
        } else {
          final roundedFeet = ((feet / 100).round() * 100);
          return '$roundedFeet feet';
        }
      }
    }
  }

  static String _formatMetricDistanceForVoice(double meters) {
    if (meters >= 1000) {
      final km = meters * _metersToKm;
      if (km >= 2.0) {
        return '${km.toStringAsFixed(0)} kilometers';
      } else {
        return '${km.toStringAsFixed(1)} kilometer';
      }
    } else {
      final roundedMeters = meters.round();
      if (roundedMeters <= 50) {
        return '$roundedMeters meters';
      } else {
        final rounded = ((roundedMeters / 50).round() * 50);
        return '$rounded meters';
      }
    }
  }

  /// Convert miles to meters for calculations
  static double milesToMeters(double miles) {
    return miles / _metersToMiles;
  }

  /// Convert meters to miles for display
  static double metersToMiles(double meters) {
    return meters * _metersToMiles;
  }

  /// Convert feet to meters for calculations  
  static double feetToMeters(double feet) {
    return feet / _metersToFeet;
  }

  /// Convert meters to feet for display
  static double metersToFeet(double meters) {
    return meters * _metersToFeet;
  }

  /// Get unit preference from user model
  static DistanceUnit getUnitFromPreferences(UserPreferences? preferences) {
    return preferences?.preferredUnits ?? DistanceUnit.imperial;
  }
}