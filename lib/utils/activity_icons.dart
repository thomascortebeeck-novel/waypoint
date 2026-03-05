import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';

/// Shared IconData for activity categories (one source of truth app-wide).
IconData getActivityIconData(ActivityCategory category) {
  switch (category) {
    case ActivityCategory.hiking:
      return Icons.hiking;
    case ActivityCategory.cycling:
      return Icons.directions_bike;
    case ActivityCategory.skis:
      return Icons.downhill_skiing;
    case ActivityCategory.climbing:
      return Icons.terrain;
    case ActivityCategory.cityTrips:
      return Icons.location_city;
    case ActivityCategory.tours:
      return Icons.tour;
    case ActivityCategory.roadTripping:
      return Icons.directions_car;
  }
}

/// Shared IconData for accommodation types.
IconData getAccommodationIconData(AccommodationType type) {
  switch (type) {
    case AccommodationType.comfort:
      return Icons.hotel;
    case AccommodationType.adventure:
      return Icons.terrain; // or Icons.camping
  }
}

/// Icon for season chips (label carries the range, e.g. "Feb – Mar").
const IconData seasonChipIcon = Icons.calendar_month;

/// Icon for location chips.
const IconData locationChipIcon = Icons.location_on;
