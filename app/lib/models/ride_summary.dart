class RideSummary {
  final String id;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;

  RideSummary({
    required this.id,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originLat': originLat,
      'originLng': originLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'destinationAddress': destinationAddress,
    };
  }

  factory RideSummary.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) throw ArgumentError('Empty ride map');
    return RideSummary(
      id: map['id'] ?? '',
      originLat: (map['originLat'] ?? 0.0).toDouble(),
      originLng: (map['originLng'] ?? 0.0).toDouble(),
      destinationLat: (map['destinationLat'] ?? 0.0).toDouble(),
      destinationLng: (map['destinationLng'] ?? 0.0).toDouble(),
      destinationAddress: map['destinationAddress'] ?? '',
    );
  }
}