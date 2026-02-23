import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/core/theme/colors.dart';

/// LEGACY: TimeSlotCategory helper functions
/// These functions are deprecated in favor of simple sequential ordering.
/// Kept for backward compatibility with existing plans.

/// Get the display label for a time slot category
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
String getTimeSlotLabel(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.breakfast:
      return 'Breakfast';
    case TimeSlotCategory.morningActivity:
      return 'Morning Activity';
    case TimeSlotCategory.allDayActivity:
      return 'All Day Activity';
    case TimeSlotCategory.lunch:
      return 'Lunch';
    case TimeSlotCategory.afternoonActivity:
      return 'Afternoon Activity';
    case TimeSlotCategory.dinner:
      return 'Dinner';
    case TimeSlotCategory.eveningActivity:
      return 'Evening Activity';
    case TimeSlotCategory.accommodation:
      return 'Accommodation';
    case TimeSlotCategory.logisticsGear:
      return 'Logistics - Gear';
    case TimeSlotCategory.logisticsTransportation:
      return 'Logistics - Transportation';
    case TimeSlotCategory.logisticsFood:
      return 'Logistics - Food';
    case TimeSlotCategory.viewingPoint:
      return 'Viewing Points';
  }
}

/// Get the icon for a time slot category (aligned with map markers)
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
IconData getTimeSlotIcon(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.breakfast:
    case TimeSlotCategory.lunch:
    case TimeSlotCategory.dinner:
      return Icons.restaurant; // Same as restaurant waypoints
    case TimeSlotCategory.morningActivity:
    case TimeSlotCategory.allDayActivity:
    case TimeSlotCategory.afternoonActivity:
    case TimeSlotCategory.eveningActivity:
      return Icons.local_activity; // Same as activity waypoints
    case TimeSlotCategory.accommodation:
      return Icons.hotel; // Same as accommodation waypoints
    case TimeSlotCategory.logisticsGear:
      return Icons.backpack;
    case TimeSlotCategory.logisticsTransportation:
      return Icons.directions_car;
    case TimeSlotCategory.logisticsFood:
      return Icons.shopping_bag;
    case TimeSlotCategory.viewingPoint:
      return Icons.visibility; // Same as viewing point waypoints
  }
}

/// Get the color for a time slot category (aligned with map markers)
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
Color getTimeSlotColor(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.breakfast:
    case TimeSlotCategory.lunch:
    case TimeSlotCategory.dinner:
      return const Color(0xFFFF9800); // Orange - same as restaurant
    case TimeSlotCategory.morningActivity:
    case TimeSlotCategory.allDayActivity:
    case TimeSlotCategory.afternoonActivity:
    case TimeSlotCategory.eveningActivity:
      return const Color(0xFF9C27B0); // Purple - same as activity
    case TimeSlotCategory.accommodation:
      return const Color(0xFF2196F3); // Blue - same as accommodation
    case TimeSlotCategory.logisticsGear:
    case TimeSlotCategory.logisticsTransportation:
    case TimeSlotCategory.logisticsFood:
      return const Color(0xFF4CAF50); // Green - same as logistics
    case TimeSlotCategory.viewingPoint:
      return const Color(0xFFFFC107); // Yellow/Gold - same as viewing point
  }
}

/// Get chronological order for time slot categories (for sorting)
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
int getTimeSlotOrder(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.breakfast:
      return 7; // 7 AM
    case TimeSlotCategory.morningActivity:
      return 9; // 9 AM
    case TimeSlotCategory.allDayActivity:
      return 8; // 8 AM (starts early, between breakfast and morning)
    case TimeSlotCategory.lunch:
      return 12; // 12 PM
    case TimeSlotCategory.afternoonActivity:
      return 14; // 2 PM
    case TimeSlotCategory.dinner:
      return 19; // 7 PM
    case TimeSlotCategory.eveningActivity:
      return 20; // 8 PM
    case TimeSlotCategory.accommodation:
      return 22; // 10 PM
    case TimeSlotCategory.logisticsGear:
    case TimeSlotCategory.logisticsTransportation:
    case TimeSlotCategory.logisticsFood:
      return 10; // Can be anywhere, default to mid-morning
    case TimeSlotCategory.viewingPoint:
      return 13; // Can be anywhere, default to midday
  }
}

/// Auto-assign time slot category based on waypoint type and sub-type
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
TimeSlotCategory? autoAssignTimeSlotCategory(RouteWaypoint waypoint) {
  // Restaurant
  if (waypoint.type == WaypointType.restaurant && waypoint.mealTime != null) {
    switch (waypoint.mealTime!) {
      case MealTime.breakfast:
        return TimeSlotCategory.breakfast;
      case MealTime.lunch:
        return TimeSlotCategory.lunch;
      case MealTime.dinner:
        return TimeSlotCategory.dinner;
    }
  }
  
  // Activity/Attraction
  if ((waypoint.type == WaypointType.attraction || waypoint.type == WaypointType.activity) && 
      waypoint.activityTime != null) {
    switch (waypoint.activityTime!) {
      case ActivityTime.morning:
        return TimeSlotCategory.morningActivity;
      case ActivityTime.allDay:
        return TimeSlotCategory.allDayActivity;
      case ActivityTime.afternoon:
        return TimeSlotCategory.afternoonActivity;
      case ActivityTime.night:
        return TimeSlotCategory.eveningActivity;
    }
  }
  
  // Bar (evening activity)
  if (waypoint.type == WaypointType.bar) {
    return TimeSlotCategory.eveningActivity;
  }
  
  // Accommodation
  if (waypoint.type == WaypointType.accommodation) {
    return TimeSlotCategory.accommodation;
  }
  
  // Service (formerly servicePoint/logistics)
  if ((waypoint.type == WaypointType.service || waypoint.type == WaypointType.servicePoint)) {
    if (waypoint.serviceCategory != null) {
      switch (waypoint.serviceCategory!) {
        case ServiceCategory.gear:
          return TimeSlotCategory.logisticsGear;
        case ServiceCategory.transportation:
        case ServiceCategory.trainStation:
        case ServiceCategory.carRental:
        case ServiceCategory.bus:
        case ServiceCategory.plane:
        case ServiceCategory.bike:
        case ServiceCategory.other:
          return TimeSlotCategory.logisticsTransportation;
        case ServiceCategory.food:
          return TimeSlotCategory.logisticsFood;
      }
    }
    // Fallback to legacy logisticsCategory
    final logisticsCat = waypoint.serviceCategory ?? waypoint.logisticsCategory;
    if (logisticsCat != null) {
      switch (logisticsCat) {
        case ServiceCategory.gear:
          return TimeSlotCategory.logisticsGear;
        case ServiceCategory.transportation:
          return TimeSlotCategory.logisticsTransportation;
        case ServiceCategory.food:
          return TimeSlotCategory.logisticsFood;
        default:
          break;
      }
    }
  }
  
  // Viewing point
  if (waypoint.type == WaypointType.viewingPoint) {
    return TimeSlotCategory.viewingPoint;
  }
  
  return null;
}

/// Get default suggested time for a time slot category (HH:MM format)
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
String? getDefaultSuggestedTime(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.breakfast:
      return '07:30';
    case TimeSlotCategory.morningActivity:
      return '09:30';
    case TimeSlotCategory.allDayActivity:
      return '08:00';
    case TimeSlotCategory.lunch:
      return '12:30';
    case TimeSlotCategory.afternoonActivity:
      return '14:00';
    case TimeSlotCategory.dinner:
      return '18:30';
    case TimeSlotCategory.eveningActivity:
      return '20:00';
    case TimeSlotCategory.accommodation:
      return '15:00'; // Check-in time
    case TimeSlotCategory.logisticsGear:
    case TimeSlotCategory.logisticsTransportation:
    case TimeSlotCategory.logisticsFood:
    case TimeSlotCategory.viewingPoint:
      return null; // No default time for these
  }
}

/// Check if a time slot category should show time input
@Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
bool shouldShowTimeInput(TimeSlotCategory category) {
  switch (category) {
    case TimeSlotCategory.logisticsGear:
    case TimeSlotCategory.logisticsTransportation:
    case TimeSlotCategory.logisticsFood:
    case TimeSlotCategory.viewingPoint:
      return false;
    default:
      return true;
  }
}

