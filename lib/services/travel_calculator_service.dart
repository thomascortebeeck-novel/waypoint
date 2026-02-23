import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/google_directions_service.dart';
import 'package:waypoint/models/plan_model.dart'; // For RouteType enum and ActivityCategory
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/services/gpx_waypoint_snapper.dart';
import 'package:waypoint/utils/haversine_utils.dart';
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
  /// [activityCategory] - Activity category to determine if GPX is required (prevents straight-line fallback)
  Future<TravelInfo?> calculateTravel({
    required ll.LatLng from,
    required ll.LatLng to,
    TravelMode? travelMode,
    bool includeGeometry = false,
    ActivityCategory? activityCategory,
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
            routeType: RouteType.directions,
          );
        }
        
        // Fallback: Straight-line route when Directions API fails
        // BUT: Don't create straight-line fallback for GPX-required activities
        // GPX-required activities: hiking, skiing, cycling, climbing
        final requiresGpx = activityCategory == ActivityCategory.hiking ||
                           activityCategory == ActivityCategory.skis ||
                           activityCategory == ActivityCategory.cycling ||
                           activityCategory == ActivityCategory.climbing;
        if (requiresGpx) {
          Log.w('travel_calculator', '⚠️ Directions API failed for GPX-required activity - cannot use straight-line fallback');
          return null; // GPX route is required, don't create direct lines
        }
        Log.w('travel_calculator', '⚠️ Directions API returned no route, using straight-line fallback');
        return _createStraightLineFallback(from, to, mode);
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
          routeType: RouteType.directions,
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
          routeType: RouteType.directions,
        );
      }

      // Final fallback: Straight-line route when all APIs fail
      Log.w('travel_calculator', '⚠️ All route APIs failed, using straight-line fallback');
      return _createStraightLineFallback(from, to, mode);
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

  /// Calculate travel information using GPX route
  /// Snaps waypoints to GPX trail and calculates distance along trail + distance to/from trail
  /// 
  /// [from] - Starting waypoint location
  /// [to] - Destination waypoint location
  /// [gpxRoute] - The GPX route to use for calculation
  /// [activityCategory] - Activity type (hiking, skiing, etc.) for time estimation
  /// Returns TravelInfo with GPX-based distance and estimated time
  Future<TravelInfo?> calculateTravelWithGpx({
    required ll.LatLng from,
    required ll.LatLng to,
    required GpxRoute gpxRoute,
    ActivityCategory? activityCategory,
  }) async {
    try {
      final snapper = GpxWaypointSnapper();
      
      // Use full resolution track points for accurate snapping
      final routePoints = gpxRoute.trackPoints.isNotEmpty 
          ? gpxRoute.trackPoints 
          : gpxRoute.simplifiedPoints;
      
      // Snap both waypoints to the GPX route
      final fromSnap = snapper.snapToRoute(from, routePoints);
      final toSnap = snapper.snapToRoute(to, routePoints);
      
      // Calculate distances:
      // 1. Distance from starting waypoint to its snap point (straight line)
      final distanceToRoute = fromSnap.distanceFromRoute; // Already in meters
      
      // 2. Distance along GPX trail between the two snap points
      final distanceAlongTrailKm = snapper.calculateDistanceAlongRouteBetweenSnaps(
        fromSnap,
        toSnap,
        routePoints,
      );
      final distanceAlongTrailM = distanceAlongTrailKm * 1000.0;
      
      // 3. Distance from destination waypoint's snap point to the waypoint (straight line)
      final distanceFromRoute = toSnap.distanceFromRoute; // Already in meters
      
      // Total distance = distance to route + distance along trail + distance from route
      final totalDistanceM = (distanceToRoute + distanceAlongTrailM + distanceFromRoute).round();
      
      // Estimate travel time based on activity type
      int durationSeconds = 0;
      if (activityCategory != null) {
        final totalDistanceKm = totalDistanceM / 1000.0;
        final estimatedDuration = snapper.estimateTravelTime(
          totalDistanceKm,
          activityCategory,
          gpxRoute.totalElevationGainM,
        );
        durationSeconds = estimatedDuration.inSeconds;
      }
      
      // Create route geometry: from waypoint -> snap point -> along trail -> snap point -> to waypoint
      final routeGeometry = <ll.LatLng>[];
      
      // Add line from starting waypoint to its snap point (if off-trail)
      if (distanceToRoute > 0) {
        routeGeometry.add(from);
        routeGeometry.add(fromSnap.snapPoint);
      } else {
        routeGeometry.add(fromSnap.snapPoint);
      }
      
      // Add points along GPX trail between snap points
      // Find the segment range between the two snap points
      final startSegment = fromSnap.segmentIndex;
      final endSegment = toSnap.segmentIndex;
      
      if (startSegment <= endSegment) {
        // Add route points between segments
        for (int i = startSegment + 1; i <= endSegment && i < routePoints.length; i++) {
          routeGeometry.add(routePoints[i]);
        }
      } else {
        // Reverse order - add points in reverse
        for (int i = startSegment; i >= endSegment && i >= 0; i--) {
          routeGeometry.add(routePoints[i]);
        }
      }
      
      // Add line from destination snap point to destination waypoint (if off-trail)
      if (distanceFromRoute > 0) {
        routeGeometry.add(toSnap.snapPoint);
        routeGeometry.add(to);
      } else {
        routeGeometry.add(toSnap.snapPoint);
      }
      
      Log.i('travel_calculator', '📏 GPX distance: ${totalDistanceM}m (to route: ${distanceToRoute}m, along trail: ${distanceAlongTrailM.toStringAsFixed(0)}m, from route: ${distanceFromRoute}m)');
      
      return TravelInfo(
        from: from,
        to: to,
        distanceMeters: totalDistanceM,
        durationSeconds: durationSeconds,
        travelMode: TravelMode.walking, // GPX routes are typically for hiking/walking
        routeGeometry: routeGeometry,
        routeType: RouteType.gpx,
      );
    } catch (e, stack) {
      Log.e('travel_calculator', '❌ GPX travel calculation failed', e, stack);
      return null;
    }
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
  /// Uses HaversineUtils for consistency
  double _calculateStraightLineDistance(ll.LatLng from, ll.LatLng to) {
    return HaversineUtils.calculateHaversineDistance(from, to);
  }

  /// Create a straight-line fallback route when APIs fail
  TravelInfo _createStraightLineFallback(ll.LatLng from, ll.LatLng to, TravelMode mode) {
    // Use HaversineUtils for accurate geodesic distance calculation
    final distanceMeters = HaversineUtils.calculateHaversineDistanceMeters(from, to).round();
    
    // Create a simple 2-point polyline for the straight line
    final routeGeometry = [from, to];
    
    return TravelInfo(
      from: from,
      to: to,
      distanceMeters: distanceMeters,
      durationSeconds: 0, // Unknown duration for straight-line routes
      travelMode: mode,
      routeGeometry: routeGeometry,
      routeType: RouteType.straightLine,
    );
  }
}

// RouteType enum moved to lib/models/plan_model.dart for shared use

/// Travel information between two points
class TravelInfo {
  final ll.LatLng from;
  final ll.LatLng to;
  final int distanceMeters;
  final int durationSeconds;
  final TravelMode travelMode;
  final List<ll.LatLng>? routeGeometry; // Route polyline geometry (from Directions API)
  final RouteType routeType; // How this route was calculated

  TravelInfo({
    required this.from,
    required this.to,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
    this.routeGeometry,
    this.routeType = RouteType.directions,
  });

  /// Whether this is a fallback route (straight-line or GPX)
  bool get isFallback => routeType != RouteType.directions;

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000.0;

  /// Duration in minutes
  int get durationMinutes => (durationSeconds / 60).round();

  /// Duration as formatted string (e.g., "2h 30m" or "45m")
  /// Returns "Duration unknown" for straight-line routes
  String get durationFormatted {
    if (routeType == RouteType.straightLine && durationSeconds == 0) {
      return 'Duration unknown';
    }
    
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

