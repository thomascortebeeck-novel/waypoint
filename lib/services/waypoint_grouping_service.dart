import 'package:waypoint/models/route_waypoint.dart';
import 'package:uuid/uuid.dart';

/// Service for managing waypoint choice groups (manual grouping via "Add alternative").
class WaypointGroupingService {
  static final WaypointGroupingService _instance = WaypointGroupingService._internal();
  factory WaypointGroupingService() => _instance;
  WaypointGroupingService._internal();

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

