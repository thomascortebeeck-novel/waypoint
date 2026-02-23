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
      case WaypointType.bar:
        return Icons.local_bar;
      case WaypointType.attraction:
        return Icons.local_activity;
      case WaypointType.accommodation:
        return Icons.hotel;
      case WaypointType.service:
        return Icons.local_convenience_store;
      case WaypointType.viewingPoint:
        return Icons.visibility;
      case WaypointType.routePoint:
        return Icons.navigation;
      case WaypointType.activity:
        return Icons.local_activity;
      case WaypointType.servicePoint:
        return Icons.local_convenience_store;
    }
  }

  /// Get color for waypoint type (used in cards and map markers)
  static Color getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.restaurant:
        return const Color(0xFFFF9800);
      case WaypointType.bar:
        return const Color(0xFFE91E63);
      case WaypointType.attraction:
        return const Color(0xFF9C27B0);
      case WaypointType.accommodation:
        return const Color(0xFF2196F3);
      case WaypointType.service:
        return const Color(0xFF4CAF50);
      case WaypointType.viewingPoint:
        return const Color(0xFFFFC107);
      case WaypointType.routePoint:
        return const Color(0xFF4CAF50);
      case WaypointType.activity:
        return const Color(0xFF9C27B0);
      case WaypointType.servicePoint:
        return const Color(0xFF4CAF50);
    }
  }
}
