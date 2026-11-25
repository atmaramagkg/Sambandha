import 'dart:math' as math;

/// Mean Earth radius in metres, used for the haversine formula.
const double earthRadiusMeters = 6371000.0;

/// Great-circle distance between two WGS84-ish coordinates, in metres.
///
/// This is accurate enough for the app's 1/3/5/10/20 km radius filter and for
/// straight-line distances between guided-route stops. It avoids depending on
/// map tiles or network access.
double haversineMeters(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  final lat1 = latitude1 * math.pi / 180.0;
  final lat2 = latitude2 * math.pi / 180.0;
  final deltaLat = (latitude2 - latitude1) * math.pi / 180.0;
  final deltaLng = (longitude2 - longitude1) * math.pi / 180.0;

  final a = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLng / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

/// Human-readable distance used by the map and guided routes.
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
