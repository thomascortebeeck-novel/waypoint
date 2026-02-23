import 'package:latlong2/latlong.dart' as ll;

/// Utility functions for geodesic distance calculations using Haversine formula
/// Uses the latlong2 package's Distance class for accurate calculations
class HaversineUtils {
  static const _distance = ll.Distance();

  /// Calculate straight-line (geodesic) distance between two points in kilometers
  /// Uses the Haversine formula via latlong2 package
  /// 
  /// [from] - Starting point (latitude, longitude)
  /// [to] - Destination point (latitude, longitude)
  /// 
  /// Returns distance in kilometers
  static double calculateHaversineDistance(ll.LatLng from, ll.LatLng to) {
    return _distance.as(
      ll.LengthUnit.Kilometer,
      from,  // Pass directly - no need to recreate LatLng objects
      to,    // Pass directly - no need to recreate LatLng objects
    );
  }

  /// Calculate straight-line distance in meters
  static double calculateHaversineDistanceMeters(ll.LatLng from, ll.LatLng to) {
    return _distance.as(
      ll.LengthUnit.Meter,
      from,  // Pass directly - no need to recreate LatLng objects
      to,    // Pass directly - no need to recreate LatLng objects
    );
  }

  /// Calculate straight-line distance in miles
  static double calculateHaversineDistanceMiles(ll.LatLng from, ll.LatLng to) {
    return _distance.as(
      ll.LengthUnit.Mile,
      from,  // Pass directly - no need to recreate LatLng objects
      to,    // Pass directly - no need to recreate LatLng objects
    );
  }
}

