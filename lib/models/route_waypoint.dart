import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';
import 'package:waypoint/core/theme/colors.dart';

// LEGACY: TimeSlotCategory helper functions moved to route_waypoint_legacy.dart
// These are kept here for backward compatibility but delegate to legacy file
import 'package:waypoint/models/route_waypoint_legacy.dart' show getTimeSlotOrder;
export 'package:waypoint/models/route_waypoint_legacy.dart' show
  getTimeSlotLabel,
  getTimeSlotIcon,
  getTimeSlotColor,
  getTimeSlotOrder,
  autoAssignTimeSlotCategory,
  getDefaultSuggestedTime,
  shouldShowTimeInput;

/// Types of POI waypoints that can be added to a route
enum WaypointType {
  restaurant,
  bar,              // New: bars and nightlife
  attraction,       // Renamed from activity
  accommodation,
  service,          // Renamed from servicePoint
  viewingPoint,
  routePoint,
  // Legacy support
  @Deprecated('Use attraction instead')
  activity,
  @Deprecated('Use service instead')
  servicePoint,
}

/// Accommodation sub-type for POI waypoints
enum POIAccommodationType {
  hotel,
  airbnb,
}

/// Meal time for restaurant waypoints
enum MealTime {
  breakfast,
  lunch,
  dinner,
}

/// Activity time for activity waypoints
enum ActivityTime {
  morning,
  afternoon,
  night,
  allDay,
}

/// Service subcategory for service waypoints
enum ServiceCategory {
  trainStation,
  carRental,
  bus,
  gear,
  transportation,
  food,
  // Add more Google transport categories as needed
}

/// Legacy alias for ServiceCategory (backward compatibility)
@Deprecated('Use ServiceCategory instead')
typedef LogisticsCategory = ServiceCategory;

/// Time slot category for organizing waypoints chronologically
/// 
/// **Deprecated**: This enum is deprecated in favor of sequential ordering.
/// 
/// Migration guide:
/// - Use `RouteWaypoint.order` for sequential positioning (1, 2, 3...)
/// - Use `RouteWaypoint.choiceGroupId` and `RouteWaypoint.choiceLabel` for grouping alternatives
/// - Legacy code will continue to work but should be migrated to the new system
/// 
/// See also: [RouteWaypoint.order], [RouteWaypoint.choiceGroupId], [RouteWaypoint.choiceLabel]
enum TimeSlotCategory {
  breakfast,
  morningActivity,
  allDayActivity,
  lunch,
  afternoonActivity,
  dinner,
  eveningActivity,
  accommodation,
  logisticsGear,
  logisticsTransportation,
  logisticsFood,
  viewingPoint,
}

/// Price range for accommodation
class PriceRange {
  final double min;
  final double max;
  final String currency;

  const PriceRange({
    required this.min,
    required this.max,
    this.currency = 'EUR',
  });

  Map<String, dynamic> toJson() => {
        'min': min,
        'max': max,
        'currency': currency,
      };

  factory PriceRange.fromJson(Map<String, dynamic> json) => PriceRange(
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
      );
}

/// A point of interest waypoint on a route
class RouteWaypoint {
  final String id;
  final WaypointType type;
  final ll.LatLng position;
  String name;
  String? description;
  int order;

  // Google Places data (for restaurants/activities/viewpoints)
  String? googlePlaceId;
  String? photoUrl;
  double? rating;
  String? website;
  String? phoneNumber;
  String? address;

  // Accommodation-specific fields
  POIAccommodationType? accommodationType; // Only for accommodation type
  String? amadeusPropertyId; // Will be used in Phase 3 for hotels
  List<String>? amenities;
  String? hotelChain;
  PriceRange? estimatedPriceRange;
  String? bookingComUrl;
  String? airbnbPropertyUrl;
  String? airbnbPropertyId;

  // Restaurant-specific fields
  MealTime? mealTime; // Only for restaurant type

  // Activity-specific fields
  ActivityTime? activityTime; // Only for activity/attraction type

  // Service-specific fields
  ServiceCategory? serviceCategory; // Only for service type
  @Deprecated('Use serviceCategory instead')
  LogisticsCategory? logisticsCategory; // Legacy support

  // Travel information (calculated automatically)
  String? travelMode; // 'walking', 'transit', 'driving', 'bicycling'
  int? travelTime; // Duration in seconds
  double? travelDistance; // Distance in meters
  List<ll.LatLng>? travelRouteGeometry; // Route polyline geometry for this segment
  
  // Day grouping for multi-day trips
  int? day; // Day number (1, 2, 3, etc.)

  // Choice group fields (for OR logic)
  /// Groups waypoints with the same order as OR options.
  /// 
  /// When multiple waypoints share the same `order` and `choiceGroupId`,
  /// they represent alternative options at that position in the route.
  /// For example, three restaurants at order 3 with the same choiceGroupId
  /// represent "pick one of these three lunch options".
  /// 
  /// Use [generateChoiceGroupId()] to create unique IDs for new choice groups.
  String? choiceGroupId;
  
  /// Display label for the choice group (e.g., "Lunch Options", "Morning Activities").
  /// 
  /// This label is shown in the UI to help users understand what the choice group represents.
  /// Use [generateAutoChoiceLabel()] to get sensible defaults based on waypoint type.
  String? choiceLabel;

  // Timeline organization
  @Deprecated('Use sequential ordering instead. TimeSlotCategory is legacy.')
  TimeSlotCategory? timeSlotCategory;
  String? suggestedStartTime; // HH:MM format (24h), set by plan builder
  String? actualStartTime; // HH:MM format (24h), set by trip owner

  // URL/Link metadata (from Open Graph extraction)
  String? linkUrl; // Original URL
  String? linkImageUrl; // Image URL extracted from Open Graph

  RouteWaypoint({
    String? id,
    required this.type,
    required this.position,
    required this.name,
    this.description,
    required this.order,
    this.googlePlaceId,
    this.photoUrl,
    this.rating,
    this.website,
    this.phoneNumber,
    this.address,
    this.accommodationType,
    this.amadeusPropertyId,
    this.amenities,
    this.hotelChain,
    this.estimatedPriceRange,
    this.bookingComUrl,
    this.airbnbPropertyUrl,
    this.airbnbPropertyId,
    this.mealTime,
    this.activityTime,
    this.serviceCategory,
    this.logisticsCategory,
    this.travelMode,
    this.travelTime,
    this.travelDistance,
    this.travelRouteGeometry,
    this.day,
    this.choiceGroupId,
    this.choiceLabel,
    this.timeSlotCategory,
    this.suggestedStartTime,
    this.actualStartTime,
    this.linkUrl,
    this.linkImageUrl,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'position': {'lat': position.latitude, 'lng': position.longitude},
        'name': name,
        if (description != null) 'description': description,
        'order': order,
        if (googlePlaceId != null) 'googlePlaceId': googlePlaceId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (rating != null) 'rating': rating,
        if (website != null) 'website': website,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (address != null) 'address': address,
        if (accommodationType != null) 'accommodationType': accommodationType!.name,
        if (amadeusPropertyId != null) 'amadeusPropertyId': amadeusPropertyId,
        if (amenities != null) 'amenities': amenities,
        if (hotelChain != null) 'hotelChain': hotelChain,
        if (estimatedPriceRange != null) 'estimatedPriceRange': estimatedPriceRange!.toJson(),
        if (bookingComUrl != null) 'bookingComUrl': bookingComUrl,
        if (airbnbPropertyUrl != null) 'airbnbPropertyUrl': airbnbPropertyUrl,
        if (airbnbPropertyId != null) 'airbnbPropertyId': airbnbPropertyId,
        if (mealTime != null) 'mealTime': mealTime!.name,
        if (activityTime != null) 'activityTime': activityTime!.name,
        if (serviceCategory != null) 'serviceCategory': serviceCategory!.name,
        if (logisticsCategory != null) 'logisticsCategory': logisticsCategory!.name,
        if (travelMode != null) 'travelMode': travelMode,
        if (travelTime != null) 'travelTime': travelTime,
        if (travelDistance != null) 'travelDistance': travelDistance,
        if (travelRouteGeometry != null) 'travelRouteGeometry': travelRouteGeometry!.map((p) => <String, double>{'lat': p.latitude, 'lng': p.longitude}).toList(),
        if (day != null) 'day': day,
        if (choiceGroupId != null) 'choiceGroupId': choiceGroupId,
        if (choiceLabel != null) 'choiceLabel': choiceLabel,
        if (timeSlotCategory != null) 'timeSlotCategory': timeSlotCategory!.name,
        if (suggestedStartTime != null) 'suggestedStartTime': suggestedStartTime,
        if (actualStartTime != null) 'actualStartTime': actualStartTime,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (linkImageUrl != null) 'linkImageUrl': linkImageUrl,
      };

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) => RouteWaypoint(
        id: json['id'] as String,
        type: _parseWaypointType(json['type'] as String?),
        position: ll.LatLng(
          (json['position']['lat'] as num).toDouble(),
          (json['position']['lng'] as num).toDouble(),
        ),
        name: json['name'] as String,
        description: json['description'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        googlePlaceId: json['googlePlaceId'] as String?,
        photoUrl: json['photoUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        website: json['website'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        address: json['address'] as String?,
        accommodationType: json['accommodationType'] != null
            ? POIAccommodationType.values.firstWhere(
                (e) => e.name == json['accommodationType'],
                orElse: () => POIAccommodationType.hotel,
              )
            : null,
        amadeusPropertyId: json['amadeusPropertyId'] as String?,
        amenities: (json['amenities'] as List?)?.cast<String>(),
        hotelChain: json['hotelChain'] as String?,
        estimatedPriceRange: json['estimatedPriceRange'] != null
            ? PriceRange.fromJson(json['estimatedPriceRange'] as Map<String, dynamic>)
            : null,
        bookingComUrl: json['bookingComUrl'] as String?,
        airbnbPropertyUrl: json['airbnbPropertyUrl'] as String?,
        airbnbPropertyId: json['airbnbPropertyId'] as String?,
        mealTime: json['mealTime'] != null
            ? MealTime.values.firstWhere(
                (e) => e.name == json['mealTime'],
                orElse: () => MealTime.lunch,
              )
            : null,
        activityTime: json['activityTime'] != null
            ? ActivityTime.values.firstWhere(
                (e) => e.name == json['activityTime'],
                orElse: () => ActivityTime.allDay,
              )
            : null,
        serviceCategory: json['serviceCategory'] != null
            ? ServiceCategory.values.firstWhere(
                (e) => e.name == json['serviceCategory'],
                orElse: () => ServiceCategory.gear,
              )
            : null,
        logisticsCategory: json['logisticsCategory'] != null
            ? LogisticsCategory.values.firstWhere(
                (e) => e.name == json['logisticsCategory'],
                orElse: () => LogisticsCategory.gear,
              )
            : null,
        travelMode: json['travelMode'] as String?,
        travelTime: json['travelTime'] as int?,
        travelDistance: (json['travelDistance'] as num?)?.toDouble(),
        travelRouteGeometry: json['travelRouteGeometry'] != null
            ? (json['travelRouteGeometry'] as List<dynamic>).map((p) {
                final map = p as Map<String, dynamic>;
                return ll.LatLng(
                  (map['lat'] as num).toDouble(),
                  (map['lng'] as num).toDouble(),
                );
              }).toList()
            : null,
        day: json['day'] as int?,
        choiceGroupId: json['choiceGroupId'] as String?,
        choiceLabel: json['choiceLabel'] as String?,
        timeSlotCategory: json['timeSlotCategory'] != null
            ? TimeSlotCategory.values.firstWhere(
                (e) => e.name == json['timeSlotCategory'],
                orElse: () => TimeSlotCategory.lunch,
              )
            : null,
        suggestedStartTime: json['suggestedStartTime'] as String?,
        actualStartTime: json['actualStartTime'] as String?,
        linkUrl: json['linkUrl'] as String?,
        linkImageUrl: json['linkImageUrl'] as String?,
      );

  RouteWaypoint copyWith({
    String? id,
    WaypointType? type,
    ll.LatLng? position,
    String? name,
    String? description,
    int? order,
    String? googlePlaceId,
    String? photoUrl,
    double? rating,
    String? website,
    String? phoneNumber,
    String? address,
    POIAccommodationType? accommodationType,
    String? amadeusPropertyId,
    List<String>? amenities,
    String? hotelChain,
    PriceRange? estimatedPriceRange,
    String? bookingComUrl,
    String? airbnbPropertyUrl,
    String? airbnbPropertyId,
    MealTime? mealTime,
    ActivityTime? activityTime,
    ServiceCategory? serviceCategory,
    LogisticsCategory? logisticsCategory,
    String? travelMode,
    int? travelTime,
    double? travelDistance,
    List<ll.LatLng>? travelRouteGeometry,
    int? day,
    String? choiceGroupId,
    String? choiceLabel,
    TimeSlotCategory? timeSlotCategory,
    Object? suggestedStartTime = _undefined,
    Object? actualStartTime = _undefined,
    String? linkUrl,
    String? linkImageUrl,
  }) =>
      RouteWaypoint(
        id: id ?? this.id,
        type: type ?? this.type,
        position: position ?? this.position,
        name: name ?? this.name,
        description: description ?? this.description,
        order: order ?? this.order,
        googlePlaceId: googlePlaceId ?? this.googlePlaceId,
        photoUrl: photoUrl ?? this.photoUrl,
        rating: rating ?? this.rating,
        website: website ?? this.website,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        address: address ?? this.address,
        accommodationType: accommodationType ?? this.accommodationType,
        amadeusPropertyId: amadeusPropertyId ?? this.amadeusPropertyId,
        amenities: amenities ?? this.amenities,
        hotelChain: hotelChain ?? this.hotelChain,
        estimatedPriceRange: estimatedPriceRange ?? this.estimatedPriceRange,
        bookingComUrl: bookingComUrl ?? this.bookingComUrl,
        airbnbPropertyUrl: airbnbPropertyUrl ?? this.airbnbPropertyUrl,
        airbnbPropertyId: airbnbPropertyId ?? this.airbnbPropertyId,
        mealTime: mealTime ?? this.mealTime,
        activityTime: activityTime ?? this.activityTime,
        serviceCategory: serviceCategory ?? this.serviceCategory,
        logisticsCategory: logisticsCategory ?? this.logisticsCategory,
        travelMode: travelMode ?? this.travelMode,
        travelTime: travelTime ?? this.travelTime,
        travelDistance: travelDistance ?? this.travelDistance,
        travelRouteGeometry: travelRouteGeometry ?? this.travelRouteGeometry,
        day: day ?? this.day,
        choiceGroupId: choiceGroupId ?? this.choiceGroupId,
        choiceLabel: choiceLabel ?? this.choiceLabel,
        timeSlotCategory: timeSlotCategory ?? this.timeSlotCategory,
        suggestedStartTime: suggestedStartTime == _undefined ? this.suggestedStartTime : suggestedStartTime as String?,
        actualStartTime: actualStartTime == _undefined ? this.actualStartTime : actualStartTime as String?,
        linkUrl: linkUrl ?? this.linkUrl,
        linkImageUrl: linkImageUrl ?? this.linkImageUrl,
      );
}

// Sentinel value for distinguishing between "not provided" and "explicitly null"
const Object _undefined = Object();

/// Parse waypoint type with backward compatibility
WaypointType _parseWaypointType(String? typeName) {
  if (typeName == null) return WaypointType.attraction;
  
  // Handle legacy types
  if (typeName == 'activity') return WaypointType.attraction;
  if (typeName == 'servicePoint') return WaypointType.service;
  
  return WaypointType.values.firstWhere(
    (e) => e.name == typeName,
    orElse: () => WaypointType.attraction,
  );
}

/// Get the icon for a waypoint type (aligned with map markers)
IconData getWaypointIcon(WaypointType type) {
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
    // Legacy support
    case WaypointType.activity:
      return Icons.local_activity;
    case WaypointType.servicePoint:
      return Icons.local_convenience_store;
  }
}

/// Get the color for a waypoint type (aligned with map markers)
/// Uses Waypoint brand colors for consistency
Color getWaypointColor(WaypointType type) {
  switch (type) {
    case WaypointType.restaurant:
      return const Color(0xFFFF9800); // Orange - keep for restaurants
    case WaypointType.bar:
      return const Color(0xFF9C27B0); // Purple - for bars/nightlife
    case WaypointType.attraction:
      return BrandColors.primary; // #2D6A4F - Primary green
    case WaypointType.accommodation:
      return BrandColors.primary; // #2D6A4F - Primary green
    case WaypointType.service:
      return BrandColors.primary; // #2D6A4F - Primary green
    case WaypointType.viewingPoint:
      return BrandColors.primary; // #2D6A4F - Primary green
    case WaypointType.routePoint:
      return BrandColors.primaryLight; // #52B788 - Lighter green for route points
    // Legacy support
    case WaypointType.activity:
      return BrandColors.primary;
    case WaypointType.servicePoint:
      return BrandColors.primary;
  }
}

/// Get the display label for a waypoint type
String getWaypointLabel(WaypointType type) {
  switch (type) {
    case WaypointType.restaurant:
      return 'Restaurant';
    case WaypointType.bar:
      return 'Bar';
    case WaypointType.attraction:
      return 'Attraction';
    case WaypointType.accommodation:
      return 'Accommodation';
    case WaypointType.service:
      return 'Service';
    case WaypointType.viewingPoint:
      return 'Viewing Point';
    case WaypointType.routePoint:
      return 'Route Point';
    // Legacy support
    case WaypointType.activity:
      return 'Attraction';
    case WaypointType.servicePoint:
      return 'Service';
  }
}

/// Get the display label for a meal time
String getMealTimeLabel(MealTime mealTime) {
  switch (mealTime) {
    case MealTime.breakfast:
      return 'Breakfast';
    case MealTime.lunch:
      return 'Lunch';
    case MealTime.dinner:
      return 'Dinner';
  }
}

/// Get the icon for a meal time
IconData getMealTimeIcon(MealTime mealTime) {
  switch (mealTime) {
    case MealTime.breakfast:
      return Icons.free_breakfast;
    case MealTime.lunch:
      return Icons.lunch_dining;
    case MealTime.dinner:
      return Icons.dinner_dining;
  }
}

/// Get the display label for an activity time
String getActivityTimeLabel(ActivityTime activityTime) {
  switch (activityTime) {
    case ActivityTime.morning:
      return 'Morning';
    case ActivityTime.afternoon:
      return 'Afternoon';
    case ActivityTime.night:
      return 'Night';
    case ActivityTime.allDay:
      return 'All Day';
  }
}

/// Get the icon for an activity time
IconData getActivityTimeIcon(ActivityTime activityTime) {
  switch (activityTime) {
    case ActivityTime.morning:
      return Icons.wb_sunny;
    case ActivityTime.afternoon:
      return Icons.wb_cloudy;
    case ActivityTime.night:
      return Icons.nightlight_round;
    case ActivityTime.allDay:
      return Icons.schedule;
  }
}

/// Get chronological order value for sorting waypoints
/// Returns a value between 0-23 representing hour of day
int getWaypointChronologicalOrder(RouteWaypoint waypoint) {
  // Use time slot category if available
  if (waypoint.timeSlotCategory != null) {
    return getTimeSlotOrder(waypoint.timeSlotCategory!);
  }
  
  // Fallback to old logic
  // Restaurants
  if (waypoint.mealTime != null) {
    switch (waypoint.mealTime!) {
      case MealTime.breakfast:
        return 7; // 7 AM
      case MealTime.lunch:
        return 12; // 12 PM
      case MealTime.dinner:
        return 19; // 7 PM
    }
  }
  
  // Activities
  if (waypoint.activityTime != null) {
    switch (waypoint.activityTime!) {
      case ActivityTime.morning:
        return 9; // 9 AM
      case ActivityTime.afternoon:
        return 14; // 2 PM
      case ActivityTime.night:
        return 20; // 8 PM
      case ActivityTime.allDay:
        return 8; // 8 AM (start of day)
    }
  }
  
  // Accommodations - typically evening/night
  if (waypoint.type == WaypointType.accommodation) {
    return 22; // 10 PM
  }
  
  // Viewing points and service points - default to midday
  return 13;
}

// ============================================================================
// Choice Group Helper Functions
// ============================================================================

/// Get all waypoints in a specific choice group
/// 
/// Choice groups allow waypoints with the same order to be displayed as
/// alternatives (OR logic). For example, multiple lunch options at order 3.
/// 
/// Example:
/// ```dart
/// final lunchOptions = getWaypointsInChoiceGroup(waypoints, 'choice_group_123');
/// ```
List<RouteWaypoint> getWaypointsInChoiceGroup(List<RouteWaypoint> waypoints, String choiceGroupId) {
  return waypoints.where((wp) => wp.choiceGroupId == choiceGroupId).toList();
}

/// Check if a waypoint is part of a choice group
/// 
/// Returns true if the waypoint has a non-null choiceGroupId.
bool isInChoiceGroup(RouteWaypoint waypoint) {
  return waypoint.choiceGroupId != null && waypoint.choiceGroupId!.isNotEmpty;
}

/// Generate a unique choice group ID
/// 
/// Uses UUID v4 to ensure uniqueness. This should be called when creating
/// a new choice group for waypoints.
String generateChoiceGroupId() {
  return const Uuid().v4();
}

/// Auto-generate a choice label based on waypoint type and time context
/// 
/// This provides sensible defaults for choice group labels based on the
/// waypoint's type and meal/activity time. Users can override this in the UI.
/// 
/// Examples:
/// - Restaurant with MealTime.lunch → "Lunch Options"
/// - Attraction with ActivityTime.morning → "Morning Activities"
/// - Restaurant with MealTime.dinner → "Dinner Options"
String generateAutoChoiceLabel(WaypointType type, MealTime? mealTime, ActivityTime? activityTime) {
  switch (type) {
    case WaypointType.restaurant:
      switch (mealTime) {
        case MealTime.breakfast:
          return 'Breakfast Options';
        case MealTime.lunch:
          return 'Lunch Options';
        case MealTime.dinner:
          return 'Dinner Options';
        case null:
          return 'Restaurant Options';
      }
    case WaypointType.bar:
      return 'Bar Options';
    case WaypointType.attraction:
    case WaypointType.activity: // Legacy support
      switch (activityTime) {
        case ActivityTime.morning:
          return 'Morning Activities';
        case ActivityTime.afternoon:
          return 'Afternoon Activities';
        case ActivityTime.night:
          return 'Evening Activities';
        case ActivityTime.allDay:
        case null:
          return 'Activity Options';
      }
    case WaypointType.accommodation:
      return 'Accommodation Options';
    case WaypointType.service:
    case WaypointType.servicePoint: // Legacy support
      return 'Service Options';
    case WaypointType.viewingPoint:
      return 'Viewing Points';
    case WaypointType.routePoint:
      return 'Route Points';
  }
}

