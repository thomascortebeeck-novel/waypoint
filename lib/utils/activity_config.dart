import 'package:waypoint/models/plan_model.dart';

/// Configuration for activity-specific behavior
class ActivityConfig {
  /// Maximum number of locations allowed (null = unlimited)
  final int? maxLocations;
  
  /// Minimum number of locations required
  final int minLocations;
  
  /// Label for location input field
  final String locationLabel;
  
  /// Whether this activity supports route planning
  final bool supportsRoutes;
  
  /// Whether location order matters (e.g., road trips)
  final bool locationOrderMatters;
  
  /// Display name for the activity
  final String displayName;
  
  /// Icon/emoji for the activity
  final String icon;

  ActivityConfig({
    this.maxLocations,
    this.minLocations = 1,
    required this.locationLabel,
    this.supportsRoutes = false,
    this.locationOrderMatters = false,
    required this.displayName,
    required this.icon,
  });
}

/// Centralized configuration for all activity types
final Map<ActivityCategory, ActivityConfig> activityConfigs = {
  ActivityCategory.hiking: ActivityConfig(
    maxLocations: null, // Unlimited (can be cross-country or city)
    minLocations: 1,
    locationLabel: 'Where are you hiking?',
    supportsRoutes: true,
    locationOrderMatters: false,
    displayName: 'Hiking',
    icon: '🥾',
  ),
  
  ActivityCategory.cycling: ActivityConfig(
    maxLocations: null, // Unlimited (can be cross-country or city)
    minLocations: 1,
    locationLabel: 'Where are you cycling?',
    supportsRoutes: true,
    locationOrderMatters: false,
    displayName: 'Cycling',
    icon: '🚴',
  ),
  
  ActivityCategory.skis: ActivityConfig(
    maxLocations: null, // Unlimited (can be cross-country or city)
    minLocations: 1,
    locationLabel: 'Where are you skiing?',
    supportsRoutes: true,
    locationOrderMatters: false,
    displayName: 'Skiing',
    icon: '⛷️',
  ),
  
  ActivityCategory.climbing: ActivityConfig(
    maxLocations: null, // Multiple locations for bouldering trips, single for specific crag
    minLocations: 1,
    locationLabel: 'Where are you climbing?',
    supportsRoutes: false,
    locationOrderMatters: false,
    displayName: 'Climbing',
    icon: '🧗',
  ),
  
  ActivityCategory.cityTrips: ActivityConfig(
    maxLocations: 1, // Single city only
    minLocations: 1,
    locationLabel: 'Which city are you visiting?',
    supportsRoutes: false,
    locationOrderMatters: false,
    displayName: 'City Trip',
    icon: '🏙️',
  ),
  
  ActivityCategory.tours: ActivityConfig(
    maxLocations: null, // Unlimited (can be cross-city or country)
    minLocations: 1,
    locationLabel: 'Add your tour destinations',
    supportsRoutes: true,
    locationOrderMatters: true, // Order matters for tours
    displayName: 'Tour',
    icon: '🌏',
  ),
  
  ActivityCategory.roadTripping: ActivityConfig(
    maxLocations: null, // Unlimited (can be cross-city or country)
    minLocations: 1,
    locationLabel: 'Add your stops in order',
    supportsRoutes: true,
    locationOrderMatters: true, // Order matters for road trips
    displayName: 'Road Trip',
    icon: '🚗',
  ),
};

/// Get configuration for an activity category
ActivityConfig? getActivityConfig(ActivityCategory? category) {
  if (category == null) return null;
  return activityConfigs[category];
}

/// Check if activity allows multiple locations
bool allowsMultipleLocations(ActivityCategory? category) {
  final config = getActivityConfig(category);
  return config?.maxLocations == null || (config!.maxLocations != null && config.maxLocations! > 1);
}

/// Check if activity requires single location
bool requiresSingleLocation(ActivityCategory? category) {
  final config = getActivityConfig(category);
  return config?.maxLocations == 1;
}

/// True when the activity uses a continuous route (e.g. trail/GPX) and does not use
/// between-waypoint transport. For these, transport mode between waypoints is hidden
/// and cannot be set (ski/hike/bike/climbing).
bool isContinuousRouteActivity(ActivityCategory? category) {
  if (category == null) return false;
  switch (category) {
    case ActivityCategory.hiking:
    case ActivityCategory.cycling:
    case ActivityCategory.skis:
    case ActivityCategory.climbing:
      return true;
    case ActivityCategory.cityTrips:
    case ActivityCategory.tours:
    case ActivityCategory.roadTripping:
      return false;
  }
}

