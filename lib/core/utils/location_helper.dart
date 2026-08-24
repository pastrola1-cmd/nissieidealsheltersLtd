import 'dart:math' as math;

class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? errorMessage;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.errorMessage,
  });

  const LocationResult.error(this.errorMessage)
      : latitude = 0.0,
        longitude = 0.0,
        accuracy = null;

  bool get isSuccess => errorMessage == null && (latitude != 0.0 || longitude != 0.0);
}

class LocationHelper {
  /// Calculates great-circle distance between two points in meters using Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // Earth radius in meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Formats distance in a human-readable format (e.g. '120 m' or '3.4 km').
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} meters';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }
}
