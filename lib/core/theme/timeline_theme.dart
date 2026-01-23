import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Timeline theme utilities for consistent icon and color mapping
/// Used across builder, trip, and plan screens
class TimelineTheme {
  TimelineTheme._();
  
  /// Get icon for time slot category (aligned with map markers)
  static IconData getIcon(TimeSlotCategory category) {
    return getTimeSlotIcon(category);
  }
  
  /// Get color for time slot category (aligned with map markers)
  static Color getColor(TimeSlotCategory category) {
    return getTimeSlotColor(category);
  }
  
  /// Get label for time slot category
  static String getLabel(TimeSlotCategory category) {
    return getTimeSlotLabel(category);
  }
  
  /// Get icon for waypoint type (used in cards and map markers)
  static IconData getWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.restaurant:
        return Icons.restaurant;
      case WaypointType.accommodation:
        return Icons.hotel;
      case WaypointType.activity:
        return Icons.local_activity;
      case WaypointType.viewingPoint:
        return Icons.visibility;
      case WaypointType.servicePoint:
        return Icons.local_convenience_store;
      case WaypointType.routePoint:
        return Icons.navigation;
    }
  }
  
  /// Get color for waypoint type (used in cards and map markers)
  static Color getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.restaurant:
        return const Color(0xFFFF9800); // Orange
      case WaypointType.accommodation:
        return const Color(0xFF2196F3); // Blue
      case WaypointType.activity:
        return const Color(0xFF9C27B0); // Purple
      case WaypointType.viewingPoint:
        return const Color(0xFFFFC107); // Yellow/Gold
      case WaypointType.servicePoint:
        return const Color(0xFF4CAF50); // Green
      case WaypointType.routePoint:
        return const Color(0xFF4CAF50); // Green
    }
  }
}
