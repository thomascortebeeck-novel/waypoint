import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_info_model.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Service for calculating route information from waypoints
class RouteInfoCalculatorService {
  /// Calculate route info from a DayRoute for auto-calculated activity types
  /// Returns RouteInfo with source: RouteInfoSource.auto
  RouteInfo? calculateFromRoute(DayRoute? route) {
    if (route == null) return null;

    // Calculate distance from route.distance (meters) or sum waypoint travel distances
    double distanceKm = 0.0;
    if (route.distance > 0) {
      distanceKm = route.distance / 1000.0; // Convert meters to km
    } else if (route.poiWaypoints.isNotEmpty) {
      // Fallback: sum travel distances from waypoints
      for (final waypointJson in route.poiWaypoints) {
        try {
          final waypoint = RouteWaypoint.fromJson(waypointJson);
          if (waypoint.travelDistance != null) {
            distanceKm += waypoint.travelDistance! / 1000.0; // Convert meters to km
          }
        } catch (e) {
          // Skip invalid waypoints
          continue;
        }
      }
    }

    // Calculate duration from route.duration (seconds) or sum waypoint travel times
    int totalSeconds = 0;
    if (route.duration > 0) {
      totalSeconds = route.duration;
    } else if (route.poiWaypoints.isNotEmpty) {
      // Fallback: sum travel times from waypoints
      for (final waypointJson in route.poiWaypoints) {
        try {
          final waypoint = RouteWaypoint.fromJson(waypointJson);
          if (waypoint.travelTime != null) {
            totalSeconds += waypoint.travelTime!;
          }
        } catch (e) {
          // Skip invalid waypoints
          continue;
        }
      }
    }

    // Format duration as "6h 30m" or "45m"
    String? estimatedTime;
    if (totalSeconds > 0) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      if (hours > 0) {
        estimatedTime = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
      } else {
        estimatedTime = '${minutes}m';
      }
    }

    // Count number of waypoints
    final numStops = route.poiWaypoints.length;

    // Only return RouteInfo if we have meaningful data
    if (distanceKm > 0 || totalSeconds > 0 || numStops > 0) {
      return RouteInfo(
        distanceKm: distanceKm > 0 ? distanceKm : null,
        estimatedTime: estimatedTime,
        numStops: numStops > 0 ? numStops : null,
        source: RouteInfoSource.auto,
      );
    }

    return null;
  }
}

/// Helper function to determine if an activity type uses auto-calculated route info
bool isAutoCalculatedActivity(ActivityCategory? activityCategory) {
  if (activityCategory == null) return false;
  
  switch (activityCategory) {
    case ActivityCategory.roadTripping:
    case ActivityCategory.cityTrips:
    case ActivityCategory.tours:
      return true;
    case ActivityCategory.hiking:
    case ActivityCategory.cycling:
    case ActivityCategory.skis:
    case ActivityCategory.climbing:
      return false;
  }
}

