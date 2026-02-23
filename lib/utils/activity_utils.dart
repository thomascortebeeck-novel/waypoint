import 'package:waypoint/models/plan_model.dart';

/// Helper to check if activity requires GPX (no direct lines allowed)
bool requiresGpxRoute(ActivityCategory? category) {
  if (category == null) return false;
  return category == ActivityCategory.hiking ||
         category == ActivityCategory.skis ||
         category == ActivityCategory.cycling ||
         category == ActivityCategory.climbing;
}

/// Helper to check if activity supports GPX routes
bool supportsGpxRoute(ActivityCategory? category) {
  if (category == null) return false;
  return category == ActivityCategory.hiking ||
         category == ActivityCategory.skis ||
         category == ActivityCategory.cycling ||
         category == ActivityCategory.climbing;
}

