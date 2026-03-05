import 'package:waypoint/models/plan_model.dart';

// =============================================================================
// Enum display names — single source for dropdowns and labels (builder + viewer)
// =============================================================================

/// User-facing label for ActivityCategory (dropdowns, plan settings).
extension ActivityCategoryDisplay on ActivityCategory {
  String get displayName {
    switch (this) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trip';
      case ActivityCategory.tours:
        return 'Tours';
      case ActivityCategory.roadTripping:
        return 'Road Tripping';
    }
  }
}

/// User-facing label for AccommodationType (dropdowns, plan settings).
extension AccommodationTypeDisplay on AccommodationType {
  String get displayName {
    switch (this) {
      case AccommodationType.comfort:
        return 'Comfort';
      case AccommodationType.adventure:
        return 'Adventure';
    }
  }
}

/// User-facing label for PlanPrivacyMode (plan settings, summary).
extension PlanPrivacyModeDisplay on PlanPrivacyMode {
  String get displayName {
    switch (this) {
      case PlanPrivacyMode.invited:
        return 'Invited';
      case PlanPrivacyMode.followers:
        return 'My Followers';
      case PlanPrivacyMode.public:
        return 'Everyone (Public)';
    }
  }
}

// =============================================================================
// Plan tag labels (card chips, tags row)
// =============================================================================

/// Returns display labels for a plan's activity category (e.g. for card tags).
/// Uses [ActivityCategory.displayName] as single source. Shared by marketplace and explore.
List<String> activityTagLabelsForPlan(Plan plan) {
  final labels = <String>[];
  final cat = plan.activityCategory;
  if (cat != null) labels.add(cat.displayName);
  return labels;
}
