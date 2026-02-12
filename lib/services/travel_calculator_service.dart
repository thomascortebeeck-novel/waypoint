import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/google_directions_service.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/utils/logger.dart';

/// Service for calculating travel time and distance between waypoints
/// Automatically selects optimal travel mode based on distance
class TravelCalculatorService {
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calculate travel information between two consecutive waypoints
  /// Automatically selects travel mode based on distance, or uses provided mode
  /// [includeGeometry] - If true, uses Directions API to get route polyline geometry.
  ///                     If false, uses Distance Matrix API for faster/cheaper calculation.
  Future<TravelInfo?> calculateTravel({
    required ll.LatLng from,
    required ll.LatLng to,
    TravelMode? travelMode,
    bool includeGeometry = false,
  }) async {
    try {
      TravelMode mode;
      if (travelMode != null) {
        mode = travelMode;
      } else {
        // First, get straight-line distance to determine mode
        final distance = _calculateStraightLineDistance(from, to);
        // Select travel mode based on distance
        mode = _selectTravelMode(distance);
      }
      
      Log.i('travel_calculator', '📏 Distance: ${_calculateStraightLineDistance(from, to).toStringAsFixed(2)}km, Mode: ${mode.name}, Geometry: $includeGeometry');

      // If geometry is needed, use Directions API (which includes distance/duration + polyline)
      if (includeGeometry) {
        final route = await _directionsService.getRoute(
          waypoints: [from, to],
          travelMode: mode,
        );

        if (route != null) {
          return TravelInfo(
            from: from,
            to: to,
            distanceMeters: route.distanceMeters.toInt(),
            durationSeconds: route.durationSeconds,
            travelMode: mode,
            routeGeometry: route.geometry,
          );
        }
        return null;
      }

      // Otherwise, use Distance Matrix API for quick/cheap calculation (no geometry)
      final matrixResult = await _getDistanceMatrix(from, to, mode);
      
      if (matrixResult != null) {
        return TravelInfo(
          from: from,
          to: to,
          distanceMeters: matrixResult.distanceMeters,
          durationSeconds: matrixResult.durationSeconds,
          travelMode: mode,
          routeGeometry: null, // Distance Matrix doesn't provide geometry
        );
      }

      // Fallback to Directions API if Distance Matrix fails
      final route = await _directionsService.getRoute(
        waypoints: [from, to],
        travelMode: mode,
      );

      if (route != null) {
        return TravelInfo(
          from: from,
          to: to,
          distanceMeters: route.distanceMeters.toInt(),
          durationSeconds: route.durationSeconds,
          travelMode: mode,
          routeGeometry: route.geometry,
        );
      }

      return null;
    } catch (e, stack) {
      Log.e('travel_calculator', '❌ Travel calculation failed', e, stack);
      return null;
    }
  }

  /// Calculate travel for all consecutive waypoint pairs in a list
  Future<List<TravelInfo?>> calculateTravelForWaypoints(
    List<RouteWaypoint> waypoints,
  ) async {
    if (waypoints.length < 2) return [];

    final results = <TravelInfo?>[];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final from = waypoints[i];
      final to = waypoints[i + 1];
      
      final travel = await calculateTravel(
        from: from.position,
        to: to.position,
      );
      
      results.add(travel);
    }

    return results;
  }

  /// Get distance matrix result from Firebase Cloud Function
  Future<DistanceMatrixResult?> _getDistanceMatrix(
    ll.LatLng from,
    ll.LatLng to,
    TravelMode travelMode,
  ) async {
    try {
      final result = await _functions.httpsCallable('googleDistanceMatrix').call({
        'origins': [
          {'lat': from.latitude, 'lng': from.longitude}
        ],
        'destinations': [
          {'lat': to.latitude, 'lng': to.longitude}
        ],
        'travelMode': travelMode.name,
      });

      if (result.data == null) return null;

      return DistanceMatrixResult.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      Log.w('travel_calculator', '⚠️ Distance Matrix API failed, will use Directions API fallback');
      return null;
    }
  }

  /// Select optimal travel mode based on straight-line distance
  TravelMode _selectTravelMode(double distanceKm) {
    if (distanceKm < 2.0) {
      return TravelMode.walking; // < 2km → walk
    } else if (distanceKm < 10.0) {
      return TravelMode.transit; // 2-10km → transit
    } else {
      return TravelMode.driving; // > 10km → drive
    }
  }

  /// Calculate straight-line distance between two points in kilometers
  double _calculateStraightLineDistance(ll.LatLng from, ll.LatLng to) {
    const distance = ll.Distance();
    return distance.as(
      ll.LengthUnit.Kilometer,
      ll.LatLng(from.latitude, from.longitude),
      ll.LatLng(to.latitude, to.longitude),
    );
  }
}

/// Travel information between two points
class TravelInfo {
  final ll.LatLng from;
  final ll.LatLng to;
  final int distanceMeters;
  final int durationSeconds;
  final TravelMode travelMode;
  final List<ll.LatLng>? routeGeometry; // Route polyline geometry (from Directions API)

  TravelInfo({
    required this.from,
    required this.to,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
    this.routeGeometry,
  });

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000.0;

  /// Duration in minutes
  int get durationMinutes => (durationSeconds / 60).round();

  /// Duration as formatted string (e.g., "2h 30m" or "45m")
  String get durationFormatted {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get icon for travel mode
  String get icon {
    switch (travelMode) {
      case TravelMode.walking:
        return '🚶'; // or use Icons.directions_walk
      case TravelMode.transit:
        return '🚌'; // or use Icons.directions_transit
      case TravelMode.driving:
        return '🚗'; // or use Icons.directions_car
      case TravelMode.bicycling:
        return '🚴'; // or use Icons.directions_bike
    }
  }

  /// Get color for travel mode
  int get color {
    switch (travelMode) {
      case TravelMode.walking:
        return 0xFF4CAF50; // Green
      case TravelMode.transit:
        return 0xFF2196F3; // Blue
      case TravelMode.driving:
        return 0xFF2196F3; // Blue
      case TravelMode.bicycling:
        return 0xFF9C27B0; // Purple
    }
  }
}

/// Distance Matrix API result
class DistanceMatrixResult {
  final int distanceMeters;
  final int durationSeconds;

  DistanceMatrixResult({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory DistanceMatrixResult.fromJson(Map<String, dynamic> json) {
    // Parse from Google Distance Matrix API response format
    final elements = json['rows'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) {
      throw Exception('Invalid Distance Matrix response');
    }

    final row = elements[0] as Map<String, dynamic>;
    final elementsList = row['elements'] as List<dynamic>?;
    if (elementsList == null || elementsList.isEmpty) {
      throw Exception('Invalid Distance Matrix response');
    }

    final element = elementsList[0] as Map<String, dynamic>;
    final distance = element['distance'] as Map<String, dynamic>?;
    final duration = element['duration'] as Map<String, dynamic>?;

    return DistanceMatrixResult(
      distanceMeters: (distance?['value'] as num?)?.toInt() ?? 0,
      durationSeconds: (duration?['value'] as num?)?.toInt() ?? 0,
    );
  }
}

