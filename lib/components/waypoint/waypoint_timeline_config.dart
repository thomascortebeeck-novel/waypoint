import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/theme/waypoint_colors.dart';

/// Configuration for waypoint category styling in timeline views
class CategoryConfig {
  final Color color;
  final IconData icon;
  final String label;

  const CategoryConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Get category configuration for a waypoint type
/// Colors match the design spec:
/// - Accommodation → green (#2D8B56)
/// - Restaurant → orange (#E8763A)
/// - Activity → blue (#3B7DD8)
/// - Transport → gray (#7B8794)
CategoryConfig getCategoryConfig(WaypointType type) {
  switch (type) {
    case WaypointType.accommodation:
      return CategoryConfig(
        color: WaypointColors.catStay, // Green
        icon: Icons.hotel,
        label: 'Accommodation',
      );
    case WaypointType.restaurant:
      return CategoryConfig(
        color: WaypointColors.catEat, // Orange
        icon: Icons.restaurant,
        label: 'Restaurant',
      );
    case WaypointType.bar:
      return CategoryConfig(
        color: WaypointColors.catEat, // Orange (same as restaurant)
        icon: Icons.local_bar,
        label: 'Bar',
      );
    case WaypointType.attraction:
    case WaypointType.activity:
      return CategoryConfig(
        color: WaypointColors.catDo, // Blue
        icon: Icons.local_activity,
        label: 'Activity',
      );
    case WaypointType.service:
    case WaypointType.servicePoint:
      return CategoryConfig(
        color: WaypointColors.catFix, // Purple - Fix/Logistics
        icon: Icons.build, // 🔧
        label: 'Fix', // Logistics/Fix
      );
    case WaypointType.viewingPoint:
      return CategoryConfig(
        color: WaypointColors.catDo, // Blue (same as activity)
        icon: Icons.visibility,
        label: 'Viewing Point',
      );
    case WaypointType.routePoint:
      return CategoryConfig(
        color: WaypointColors.textTertiary, // Gray
        icon: Icons.place,
        label: 'Route Point',
      );
  }
}

