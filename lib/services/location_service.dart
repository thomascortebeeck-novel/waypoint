import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Result of getting current location (position, permission, or error).
class LocationResult {
  final Position? position;
  final LocationPermission permission;
  final String? error;

  const LocationResult({this.position, required this.permission, this.error});

  bool get hasPosition => position != null;
}

/// One-shot and distance helpers for check-in. No background tracking.
class LocationService {
  /// Request permission and get current position. High accuracy, 10s timeout.
  Future<LocationResult> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return LocationResult(
            permission: requested,
            error: requested == LocationPermission.deniedForever
                ? 'Location permanently denied'
                : 'Location denied',
          );
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          permission: LocationPermission.deniedForever,
          error: 'Location permanently denied',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 10),
      );
      return LocationResult(
        position: position,
        permission: await Geolocator.checkPermission(),
      );
    } catch (e) {
      return LocationResult(
        permission: LocationPermission.denied,
        error: e.toString(),
      );
    }
  }

  /// Distance in metres between two points.
  static double distanceTo(ll.LatLng from, ll.LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Whether [current] is within [radiusM] metres of [target].
  static bool isWithinRadius(
    ll.LatLng current,
    ll.LatLng target, {
    double radiusM = 200,
  }) {
    return distanceTo(current, target) <= radiusM;
  }
}
