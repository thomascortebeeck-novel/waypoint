import 'package:waypoint/models/route_waypoint.dart';
import 'package:uuid/uuid.dart';

/// Service for detecting and managing waypoint choice groups
/// Handles auto-grouping suggestions when matching waypoints are detected
class WaypointGroupingService {
  static final WaypointGroupingService _instance = WaypointGroupingService._internal();
  factory WaypointGroupingService() => _instance;
  WaypointGroupingService._internal();

  /// Check if a new waypoint should be auto-grouped with existing waypoints
  /// Returns the existing waypoint that matches, or null if no match
  RouteWaypoint? shouldAutoGroup(
    List<RouteWaypoint> existingWaypoints,
    RouteWaypoint newWaypoint,
  ) {
    // Find waypoints at the same order position
    final waypointsAtOrder = findWaypointsAtOrder(existingWaypoints, newWaypoint.order);
    
    if (waypointsAtOrder.isEmpty) {
      return null;
    }

    // Check trigger conditions
    for (final existing in waypointsAtOrder) {
      // Condition 1: Same order AND same type
      if (existing.type == newWaypoint.type) {
        return existing;
      }

      // Condition 2: Same order AND overlapping time labels
      if (_hasOverlappingTimeLabels(existing, newWaypoint)) {
        return existing;
      }
    }

    // Condition 3: Waypoint added to position where same type exists
    // (This is already covered by condition 1, but we check all waypoints at order)
    for (final existing in waypointsAtOrder) {
      if (existing.type == newWaypoint.type) {
        return existing;
      }
    }

    return null;
  }

  /// Check if two waypoints have overlapping time labels
  bool _hasOverlappingTimeLabels(RouteWaypoint a, RouteWaypoint b) {
    // Check meal times (both lunch, both dinner, etc.)
    if (a.mealTime != null && b.mealTime != null && a.mealTime == b.mealTime) {
      return true;
    }

    // Check activity times (both morning, both afternoon, etc.)
    if (a.activityTime != null && b.activityTime != null && a.activityTime == b.activityTime) {
      return true;
    }

    // Check suggested times (within 1 hour)
    if (a.suggestedStartTime != null && b.suggestedStartTime != null) {
      final timeA = _parseTime(a.suggestedStartTime!);
      final timeB = _parseTime(b.suggestedStartTime!);
      if (timeA != null && timeB != null) {
        final diff = timeA.difference(timeB).abs();
        if (diff.inHours < 1) {
          return true;
        }
      }
    }

    return false;
  }

  /// Parse time string (HH:MM) to DateTime (today)
  DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  /// Find existing waypoints at the same order position
  List<RouteWaypoint> findWaypointsAtOrder(List<RouteWaypoint> waypoints, int order) {
    return waypoints.where((wp) => wp.order == order).toList();
  }

  /// Generate auto choice label from type and time
  /// Returns null if no label can be generated
  String? generateAutoChoiceLabel(
    WaypointType type,
    String? suggestedTime,
    MealTime? mealTime,
    ActivityTime? activityTime,
  ) {
    // Restaurant + meal time
    if (type == WaypointType.restaurant && mealTime != null) {
      switch (mealTime) {
        case MealTime.breakfast:
          return 'Breakfast Options';
        case MealTime.lunch:
          return 'Lunch Options';
        case MealTime.dinner:
          return 'Dinner Options';
      }
    }

    // Activity/Attraction + activity time
    if ((type == WaypointType.attraction || type == WaypointType.activity) && 
        activityTime != null) {
      switch (activityTime) {
        case ActivityTime.morning:
          return 'Morning Activities';
        case ActivityTime.afternoon:
          return 'Afternoon Activities';
        case ActivityTime.night:
          return 'Evening Activities';
        case ActivityTime.allDay:
          return 'Activity Options';
      }
    }

    // Bar (evening activity)
    if (type == WaypointType.bar) {
      return 'Evening Options';
    }

    // Same type + same order (no time) → "[Type] Options"
    switch (type) {
      case WaypointType.restaurant:
        return 'Restaurant Options';
      case WaypointType.bar:
        return 'Bar Options';
      case WaypointType.attraction:
      case WaypointType.activity:
        return 'Attraction Options';
      case WaypointType.accommodation:
        return 'Accommodation Options';
      case WaypointType.service:
      case WaypointType.servicePoint:
        return 'Service Options';
      case WaypointType.viewingPoint:
        return 'Viewing Point Options';
      case WaypointType.routePoint:
        return null; // Route points shouldn't be in choice groups
    }
  }

  /// Create a choice group ID
  String generateChoiceGroupId() {
    return 'choice_${const Uuid().v4()}';
  }

  /// Group waypoints into a choice group
  /// Assigns same choiceGroupId and choiceLabel to all waypoints
  List<RouteWaypoint> groupWaypoints(
    List<RouteWaypoint> waypoints,
    String choiceGroupId,
    String choiceLabel,
  ) {
    return waypoints.map((wp) {
      return wp.copyWith(
        choiceGroupId: choiceGroupId,
        choiceLabel: choiceLabel,
      );
    }).toList();
  }

  /// Ungroup waypoints (split into separate order numbers)
  /// Increments order for waypoints after the first one
  List<RouteWaypoint> ungroupWaypoints(List<RouteWaypoint> waypoints) {
    if (waypoints.isEmpty) return waypoints;
    
    final result = <RouteWaypoint>[];
    final baseOrder = waypoints.first.order;
    
    for (int i = 0; i < waypoints.length; i++) {
      result.add(waypoints[i].copyWith(
        order: baseOrder + i,
        choiceGroupId: null,
        choiceLabel: null,
      ));
    }
    
    return result;
  }

  /// Get all waypoints in a choice group
  List<RouteWaypoint> getChoiceGroupWaypoints(
    List<RouteWaypoint> allWaypoints,
    String choiceGroupId,
  ) {
    return allWaypoints
        .where((wp) => wp.choiceGroupId == choiceGroupId)
        .toList();
  }

  /// Check if waypoint is part of a choice group
  bool isInChoiceGroup(RouteWaypoint waypoint) {
    return waypoint.choiceGroupId != null && waypoint.choiceGroupId!.isNotEmpty;
  }

  /// Get choice group label for a waypoint (or null if not in group)
  String? getChoiceGroupLabel(RouteWaypoint waypoint) {
    return waypoint.choiceLabel;
  }
}

