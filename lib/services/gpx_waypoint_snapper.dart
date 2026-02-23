import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/utils/haversine_utils.dart';

/// Result of snapping a waypoint to a GPX route
class SnapResult {
  final ll.LatLng snapPoint; // Closest point on GPX route
  final double distanceFromRoute; // How far the waypoint is from the trail (meters)
  final double distanceAlongRoute; // Cumulative distance from route start (km)
  final int segmentIndex; // Which GPX segment it snapped to

  SnapResult({
    required this.snapPoint,
    required this.distanceFromRoute,
    required this.distanceAlongRoute,
    required this.segmentIndex,
  });
}

/// Service for snapping waypoints to GPX routes and calculating travel metrics
class GpxWaypointSnapper {
  /// Find the closest point on the GPX route for a given waypoint
  /// 
  /// [waypointLocation] - The waypoint's actual location
  /// [routePoints] - The GPX route points (can be full or simplified)
  /// Returns SnapResult with the closest point on the route
  SnapResult snapToRoute(ll.LatLng waypointLocation, List<ll.LatLng> routePoints) {
    if (routePoints.isEmpty) {
      throw ArgumentError('Route points cannot be empty');
    }

    if (routePoints.length == 1) {
      // Single point route - snap directly to it
      final distance = HaversineUtils.calculateHaversineDistanceMeters(
        waypointLocation,
        routePoints.first,
      );
      return SnapResult(
        snapPoint: routePoints.first,
        distanceFromRoute: distance,
        distanceAlongRoute: 0.0,
        segmentIndex: 0,
      );
    }

    double minDistance = double.infinity;
    ll.LatLng? closestPoint;
    int closestSegmentIndex = 0;
    double cumulativeDistance = 0.0;
    double distanceAlongRoute = 0.0;

    // Iterate through consecutive route point pairs (line segments)
    for (int i = 0; i < routePoints.length - 1; i++) {
      final p1 = routePoints[i];
      final p2 = routePoints[i + 1];

      // Calculate perpendicular distance from waypoint to this segment
      final projection = _projectPointOntoLineSegment(waypointLocation, p1, p2);
      final distance = HaversineUtils.calculateHaversineDistanceMeters(
        waypointLocation,
        projection,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = projection;
        closestSegmentIndex = i;
        // Calculate distance along route to this segment
        distanceAlongRoute = cumulativeDistance;
        // Add distance from segment start to projection point
        distanceAlongRoute += HaversineUtils.calculateHaversineDistance(
          p1,
          projection,
        );
      }

      // Add segment length to cumulative distance
      cumulativeDistance += HaversineUtils.calculateHaversineDistance(p1, p2);
    }

    return SnapResult(
      snapPoint: closestPoint!,
      distanceFromRoute: minDistance,
      distanceAlongRoute: distanceAlongRoute,
      segmentIndex: closestSegmentIndex,
    );
  }

  /// Project a point onto a line segment and return the closest point on the segment
  /// 
  /// Uses vector projection to find the closest point on the line segment
  ll.LatLng _projectPointOntoLineSegment(
    ll.LatLng point,
    ll.LatLng segmentStart,
    ll.LatLng segmentEnd,
  ) {
    // Convert to approximate local coordinates (meters) for projection
    // Using simple approximation for small distances
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;
    final px = point.longitude - segmentStart.longitude;
    final py = point.latitude - segmentStart.latitude;

    // Calculate projection parameter t
    final dot = px * dx + py * dy;
    final lenSq = dx * dx + dy * dy;
    
    if (lenSq == 0) {
      // Segment is a point
      return segmentStart;
    }

    final t = (dot / lenSq).clamp(0.0, 1.0);

    // Calculate projected point
    return ll.LatLng(
      segmentStart.latitude + t * dy,
      segmentStart.longitude + t * dx,
    );
  }

  /// Snap all waypoints to the GPX route and calculate inter-waypoint distances/times
  /// 
  /// [waypoints] - List of waypoints to snap
  /// [route] - The GPX route to snap to
  /// Returns list of SnapResult for each waypoint
  List<SnapResult> snapAllWaypoints(List<RouteWaypoint> waypoints, GpxRoute route) {
    final results = <SnapResult>[];
    
    // Use full resolution track points for accurate snapping
    final routePoints = route.trackPoints.isNotEmpty 
        ? route.trackPoints 
        : route.simplifiedPoints;

    for (final waypoint in waypoints) {
      final snapResult = snapToRoute(waypoint.position, routePoints);
      results.add(snapResult);
    }

    return results;
  }

  /// Estimate travel time between two points along the route
  /// 
  /// [distanceKm] - Distance in kilometers
  /// [activityType] - Activity category (hiking, cycling, etc.)
  /// [elevationGainM] - Elevation gain in meters (optional)
  /// Returns estimated duration
  Duration estimateTravelTime(
    double distanceKm,
    ActivityCategory activityType,
    double? elevationGainM,
  ) {
    // Base speeds (km/h) for different activities
    double baseSpeed;
    switch (activityType) {
      case ActivityCategory.hiking:
        baseSpeed = 4.0; // 4 km/h for hiking
        break;
      case ActivityCategory.cycling:
        baseSpeed = 15.0; // 15 km/h for cycling
        break;
      case ActivityCategory.climbing:
        baseSpeed = 2.0; // 2 km/h for climbing
        break;
      case ActivityCategory.skis:
        baseSpeed = 10.0; // 10 km/h for skiing
        break;
      default:
        baseSpeed = 4.0; // Default to hiking speed
    }

    // Adjust speed for elevation gain
    // Rough estimate: 100m elevation gain ≈ 10-15 minutes extra time
    double adjustedSpeed = baseSpeed;
    if (elevationGainM != null && elevationGainM > 0) {
      // Reduce speed based on elevation gain
      // For every 100m elevation, reduce speed by ~5%
      final elevationFactor = 1.0 - (elevationGainM / 100.0) * 0.05;
      adjustedSpeed = baseSpeed * elevationFactor.clamp(0.3, 1.0);
    }

    // Calculate time: time = distance / speed
    final hours = distanceKm / adjustedSpeed;
    final totalMinutes = (hours * 60).round();

    return Duration(minutes: totalMinutes);
  }

  /// Calculate cumulative distance along route from start to a given point
  /// 
  /// [routePoints] - The GPX route points
  /// [targetIndex] - Index of the target point (0-based)
  /// Returns cumulative distance in kilometers
  double calculateDistanceAlongRoute(List<ll.LatLng> routePoints, int targetIndex) {
    if (targetIndex <= 0) return 0.0;
    if (targetIndex >= routePoints.length) {
      targetIndex = routePoints.length - 1;
    }

    double totalDistance = 0.0;
    for (int i = 0; i < targetIndex; i++) {
      totalDistance += HaversineUtils.calculateHaversineDistance(
        routePoints[i],
        routePoints[i + 1],
      );
    }
    return totalDistance;
  }

  /// Calculate distance along GPX trail between two snap points
  /// Uses the cumulative distanceAlongRoute values for accurate calculation
  /// 
  /// [fromSnapResult] - Snap result for the starting waypoint
  /// [toSnapResult] - Snap result for the destination waypoint
  /// [routePoints] - Full GPX route points (for fallback calculation if needed)
  /// Returns distance in kilometers
  double calculateDistanceAlongRouteBetweenSnaps(
    SnapResult fromSnapResult,
    SnapResult toSnapResult,
    List<ll.LatLng> routePoints,
  ) {
    // Use the simpler approach: difference in cumulative distance
    // If waypoints are in order along the route
    if (fromSnapResult.distanceAlongRoute <= toSnapResult.distanceAlongRoute) {
      // Calculate distance from fromSnapResult.snapPoint to the next route point
      // Then add the distance along route between the two snap points
      // Then add distance from previous route point to toSnapResult.snapPoint
      
      double distance = 0.0;
      
      // If snap points are on different segments or far apart, use cumulative distance
      // Otherwise, calculate precise distance along the route
      if (fromSnapResult.segmentIndex < toSnapResult.segmentIndex) {
        // Different segments - use cumulative distance as base
        distance = toSnapResult.distanceAlongRoute - fromSnapResult.distanceAlongRoute;
      } else if (fromSnapResult.segmentIndex == toSnapResult.segmentIndex) {
        // Same segment - use direct distance between snap points
        distance = HaversineUtils.calculateHaversineDistance(
          fromSnapResult.snapPoint,
          toSnapResult.snapPoint,
        );
      } else {
        // Reverse order - swap and recalculate
        return calculateDistanceAlongRouteBetweenSnaps(toSnapResult, fromSnapResult, routePoints);
      }
      
      return distance;
    } else {
      // Waypoints are in reverse order - swap them
      return calculateDistanceAlongRouteBetweenSnaps(toSnapResult, fromSnapResult, routePoints);
    }
  }

  /// Calculate distance along route between two snap points (legacy method using segment indices)
  /// 
  /// [routePoints] - The GPX route points
  /// [snap1] - First snap result
  /// [snap2] - Second snap result
  /// Returns distance in kilometers
  double calculateDistanceBetweenSnaps(
    List<ll.LatLng> routePoints,
    SnapResult snap1,
    SnapResult snap2,
  ) {
    // Calculate distance from snap1 to end of its segment
    double distance = 0.0;
    
    if (snap1.segmentIndex < snap2.segmentIndex) {
      // snap1 is before snap2
      // Distance from snap1 to end of its segment
      if (snap1.segmentIndex < routePoints.length - 1) {
        distance += HaversineUtils.calculateHaversineDistance(
          snap1.snapPoint,
          routePoints[snap1.segmentIndex + 1],
        );
      }
      
      // Distance through intermediate segments
      for (int i = snap1.segmentIndex + 1; i < snap2.segmentIndex; i++) {
        distance += HaversineUtils.calculateHaversineDistance(
          routePoints[i],
          routePoints[i + 1],
        );
      }
      
      // Distance from start of snap2's segment to snap2
      if (snap2.segmentIndex < routePoints.length - 1) {
        distance += HaversineUtils.calculateHaversineDistance(
          routePoints[snap2.segmentIndex],
          snap2.snapPoint,
        );
      }
    } else if (snap1.segmentIndex > snap2.segmentIndex) {
      // snap1 is after snap2 - reverse the calculation
      return calculateDistanceBetweenSnaps(routePoints, snap2, snap1);
    } else {
      // Both snaps are on the same segment
      distance = HaversineUtils.calculateHaversineDistance(
        snap1.snapPoint,
        snap2.snapPoint,
      );
    }

    return distance;
  }

  /// Validate waypoint order against GPX route direction
  /// 
  /// [snapResults] - List of snap results for waypoints
  /// Returns true if waypoints are in order along the route
  bool validateWaypointOrder(List<SnapResult> snapResults) {
    if (snapResults.length <= 1) return true;

    for (int i = 0; i < snapResults.length - 1; i++) {
      if (snapResults[i].distanceAlongRoute > snapResults[i + 1].distanceAlongRoute) {
        return false;
      }
    }
    return true;
  }
}

