import 'ride_model.dart';

class RideSearchResult {
  final RideOffer offer;
  final double pickupDistanceKm;
  final double dropoffDistanceKm;
  final int departureDeltaMinutes;
  final double score;
  final int qualityScore; // 0-100, higher is better for UI indicators

  const RideSearchResult({
    required this.offer,
    required this.pickupDistanceKm,
    required this.dropoffDistanceKm,
    required this.departureDeltaMinutes,
    required this.score,
    required this.qualityScore,
  });
}
