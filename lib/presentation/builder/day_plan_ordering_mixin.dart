import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/orderable_item.dart';

/// Mixin that adds day plan ordering functionality
/// Use in both BuilderScreen and RouteBuilderScreen
mixin DayPlanOrderingMixin<T extends StatefulWidget> on State<T> {
  // Store order manager for each day
  // Key = day number, Value = order manager
  Map<int, DayPlanOrderManager> _orderByDay = {};
  
  // Your waypoints list (override in actual implementation)
  List<RouteWaypoint> get waypoints;
  
  /// Initialize ordering from waypoints
  void initializeOrdering() {
    final waypointsByDay = <int, List<RouteWaypoint>>{};
    
    for (final wp in waypoints) {
      final day = wp.dayNumber ?? 1;
      waypointsByDay.putIfAbsent(day, () => []).add(wp);
    }
    
    for (final entry in waypointsByDay.entries) {
      _orderByDay[entry.key] = DayPlanOrderBuilder.buildFromWaypoints(
        entry.key,
        entry.value,
      );
    }
  }
  
  /// Move an item up within a day
  void moveItemUp(int day, String itemId) {
    setState(() {
      final manager = _orderByDay[day];
      if (manager != null) {
        _orderByDay[day] = manager.moveUp(itemId);
      }
    });
  }
  
  /// Move an item down within a day
  void moveItemDown(int day, String itemId) {
    setState(() {
      final manager = _orderByDay[day];
      if (manager != null) {
        _orderByDay[day] = manager.moveDown(itemId);
      }
    });
  }
  
  /// Check if item can move up
  bool canItemMoveUp(int day, String itemId) {
    return _orderByDay[day]?.canMoveUp(itemId) ?? false;
  }
  
  /// Check if item can move down
  bool canItemMoveDown(int day, String itemId) {
    return _orderByDay[day]?.canMoveDown(itemId) ?? false;
  }
  
  /// Get ordered items for a day
  List<OrderableItem> getOrderedItems(int day) {
    return _orderByDay[day]?.sortedItems ?? [];
  }
  
  /// Build waypoints map by section ID
  Map<String, List<RouteWaypoint>> buildWaypointsBySectionId(int day) {
    final dayWaypoints = waypoints.where((wp) => (wp.dayNumber ?? 1) == day).toList();
    final map = <String, List<RouteWaypoint>>{};
    
    for (final wp in dayWaypoints) {
      final sectionId = _getSectionIdForWaypoint(wp);
      if (sectionId != null) {
        map.putIfAbsent(sectionId, () => []).add(wp);
      }
    }
    
    return map;
  }
  
  /// Build waypoints map by ID (for individual waypoints)
  Map<String, RouteWaypoint> buildWaypointsById(int day) {
    final dayWaypoints = waypoints.where((wp) => (wp.dayNumber ?? 1) == day).toList();
    return { for (final wp in dayWaypoints) wp.id: wp };
  }
  
  String? _getSectionIdForWaypoint(RouteWaypoint wp) {
    switch (wp.type) {
      case WaypointType.restaurant:
        return 'restaurantSection_${wp.mealTime?.name ?? "lunch"}';
      case WaypointType.activity:
        return 'activitySection_${wp.activityTime?.name ?? "afternoon"}';
      case WaypointType.accommodation:
        return 'accommodationSection';
      case WaypointType.servicePoint:
        // For logistics, each waypoint is its own item (not a section)
        return null;
      case WaypointType.viewingPoint:
        // For viewing points, each waypoint is its own item (not a section)
        return null;
      case WaypointType.routePoint:
        return null;
    }
  }
  
  /// Call when waypoints change to update ordering
  void onWaypointsChanged() {
    initializeOrdering();
  }
  
  /// Get the waypoint ID for an individual waypoint item
  String? getWaypointIdForItem(OrderableItem item) {
    if (item.isIndividualWaypoint) {
      return item.waypointId;
    }
    return null;
  }
}

