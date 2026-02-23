import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/gpx_route_model.dart';

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

/// Accommodation sub-type for POI waypoints (Sleep)
enum POIAccommodationType {
  hotel,
  airbnb,
  bedAndBreakfast,
  hostel,
  camping,
  vacationRental,
}

/// Eat & Drink subcategory (distinct from WaypointType.restaurant)
enum EatCategory {
  diningRestaurant,
  cafe,
  bar,
  quickBite,
  bakery,
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

/// Do & See (attraction) subcategory
enum AttractionCategory {
  sightsAndLandmarks,
  museumsAndCulture,
  natureAndOutdoors,
  toursAndExperiences,
  entertainment,
  nightlife,
  sportsAndActivities,
}

/// See (viewingPoint) subcategory
enum SightCategory {
  landmark,
  viewpoint,
  scenicSpot,
  observationDeck,
  monument,
}

/// Service subcategory for service waypoints (Move)
enum ServiceCategory {
  trainStation,
  carRental,
  bus,
  plane,
  bike,
  other,
  gear,
  transportation,
  food,
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

/// Snapping information for a waypoint on a GPX route
class WaypointSnapInfo {
  final ll.LatLng snapPoint; // Closest point on GPX route
  final ll.LatLng originalPosition; // Original waypoint position before snapping
  final double distanceFromRouteM; // How far the waypoint is from the trail (meters)
  final double distanceAlongRouteKm; // Cumulative distance from route start (km)
  final int segmentIndex; // Which GPX segment it snapped to

  WaypointSnapInfo({
    required this.snapPoint,
    required this.originalPosition,
    required this.distanceFromRouteM,
    required this.distanceAlongRouteKm,
    required this.segmentIndex,
  });

  Map<String, dynamic> toJson() => {
        'snapPoint': {
          'lat': snapPoint.latitude,
          'lng': snapPoint.longitude,
        },
        'originalPosition': {
          'lat': originalPosition.latitude,
          'lng': originalPosition.longitude,
        },
        'distanceFromRouteM': distanceFromRouteM,
        'distanceAlongRouteKm': distanceAlongRouteKm,
        'segmentIndex': segmentIndex,
      };

  factory WaypointSnapInfo.fromJson(Map<String, dynamic> json) {
    final snapPointJson = json['snapPoint'] as Map<String, dynamic>;
    // Handle backward compatibility: if originalPosition is missing, use snapPoint
    final originalPositionJson = json['originalPosition'] as Map<String, dynamic>?;
    final originalPosition = originalPositionJson != null
        ? ll.LatLng(
            (originalPositionJson['lat'] as num).toDouble(),
            (originalPositionJson['lng'] as num).toDouble(),
          )
        : ll.LatLng(
            (snapPointJson['lat'] as num).toDouble(),
            (snapPointJson['lng'] as num).toDouble(),
          );
    
    return WaypointSnapInfo(
      snapPoint: ll.LatLng(
        (snapPointJson['lat'] as num).toDouble(),
        (snapPointJson['lng'] as num).toDouble(),
      ),
      originalPosition: originalPosition,
      distanceFromRouteM: (json['distanceFromRouteM'] as num).toDouble(),
      distanceAlongRouteKm: (json['distanceAlongRouteKm'] as num).toDouble(),
      segmentIndex: (json['segmentIndex'] as num).toInt(),
    );
  }
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
  /// First photo URL; kept for backward compatibility. Prefer [photoUrls] when non-empty.
  String? photoUrl;
  /// Ordered list of photo storage URLs (Google-cached + user uploads). When non-empty, [photoUrl] should match first.
  List<String>? photoUrls;
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
  /// Single price estimate; preferred over [estimatedPriceRange] when set.
  double? estimatedPrice;
  /// Subcategory tags (display labels); authoritative. First tag is written back to typed field for legacy.
  List<String>? subCategoryTags;
  String? bookingComUrl;
  String? airbnbPropertyUrl;
  String? airbnbPropertyId;

  // Restaurant-specific fields
  EatCategory? eatCategory; // Eat & Drink subcategory
  MealTime? mealTime; // Only for restaurant type

  // Activity-specific fields
  AttractionCategory? attractionCategory; // Do & See subcategory
  ActivityTime? activityTime; // Only for activity/attraction type

  // See (viewingPoint) subcategory
  SightCategory? sightCategory;

  // Service-specific fields
  ServiceCategory? serviceCategory; // Only for service type
  @Deprecated('Use serviceCategory instead')
  LogisticsCategory? logisticsCategory; // Legacy support

  // Travel information (calculated automatically)
  String? travelMode; // 'walking', 'transit', 'driving', 'bicycling'
  int? travelTime; // Duration in seconds
  double? travelDistance; // Distance in meters
  List<ll.LatLng>? travelRouteGeometry; // Route polyline geometry for this segment
  
  // GPX route snapping information (when waypoint is snapped to imported GPX route)
  WaypointSnapInfo? waypointSnapInfo;
  
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
    this.photoUrls,
    this.rating,
    this.website,
    this.phoneNumber,
    this.address,
    this.accommodationType,
    this.amadeusPropertyId,
    this.amenities,
    this.hotelChain,
    this.estimatedPriceRange,
    this.estimatedPrice,
    this.subCategoryTags,
    this.bookingComUrl,
    this.airbnbPropertyUrl,
    this.airbnbPropertyId,
    this.eatCategory,
    this.mealTime,
    this.attractionCategory,
    this.activityTime,
    this.sightCategory,
    this.serviceCategory,
    this.logisticsCategory,
    this.travelMode,
    this.travelTime,
    this.travelDistance,
    this.travelRouteGeometry,
    this.waypointSnapInfo,
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
        if (photoUrls != null && photoUrls!.isNotEmpty) 'photoUrls': photoUrls,
        if ((photoUrls != null && photoUrls!.isNotEmpty) || photoUrl != null)
          'photoUrl': (photoUrls != null && photoUrls!.isNotEmpty) ? photoUrls!.first : photoUrl,
        if (rating != null) 'rating': rating,
        if (website != null) 'website': website,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (address != null) 'address': address,
        if (accommodationType != null) 'accommodationType': accommodationType!.name,
        if (amadeusPropertyId != null) 'amadeusPropertyId': amadeusPropertyId,
        if (amenities != null) 'amenities': amenities,
        if (hotelChain != null) 'hotelChain': hotelChain,
        if (estimatedPriceRange != null) 'estimatedPriceRange': estimatedPriceRange!.toJson(),
        if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
        if (subCategoryTags != null) 'subCategoryTags': subCategoryTags,
        if (bookingComUrl != null) 'bookingComUrl': bookingComUrl,
        if (airbnbPropertyUrl != null) 'airbnbPropertyUrl': airbnbPropertyUrl,
        if (airbnbPropertyId != null) 'airbnbPropertyId': airbnbPropertyId,
        if (eatCategory != null) 'eatCategory': eatCategory!.name,
        if (mealTime != null) 'mealTime': mealTime!.name,
        if (attractionCategory != null) 'attractionCategory': attractionCategory!.name,
        if (activityTime != null) 'activityTime': activityTime!.name,
        if (sightCategory != null) 'sightCategory': sightCategory!.name,
        if (serviceCategory != null) 'serviceCategory': serviceCategory!.name,
        if (logisticsCategory != null) 'logisticsCategory': logisticsCategory!.name,
        if (travelMode != null) 'travelMode': travelMode,
        if (travelTime != null) 'travelTime': travelTime,
        if (travelDistance != null) 'travelDistance': travelDistance,
        if (travelRouteGeometry != null) 'travelRouteGeometry': travelRouteGeometry!.map((p) => <String, double>{'lat': p.latitude, 'lng': p.longitude}).toList(),
        if (waypointSnapInfo != null) 'waypointSnapInfo': waypointSnapInfo!.toJson(),
        if (day != null) 'day': day,
        if (choiceGroupId != null) 'choiceGroupId': choiceGroupId,
        if (choiceLabel != null) 'choiceLabel': choiceLabel,
        if (timeSlotCategory != null) 'timeSlotCategory': timeSlotCategory!.name,
        if (suggestedStartTime != null) 'suggestedStartTime': suggestedStartTime,
        if (actualStartTime != null) 'actualStartTime': actualStartTime,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (linkImageUrl != null) 'linkImageUrl': linkImageUrl,
      };

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    final accommodationType = json['accommodationType'] != null
        ? POIAccommodationType.values.firstWhere(
            (e) => e.name == json['accommodationType'],
            orElse: () => POIAccommodationType.hotel,
          )
        : null;
    final eatCategory = json['eatCategory'] != null
        ? EatCategory.values.firstWhere(
            (e) => e.name == json['eatCategory'],
            orElse: () => EatCategory.diningRestaurant,
          )
        : null;
    final attractionCategory = json['attractionCategory'] != null
        ? AttractionCategory.values.firstWhere(
            (e) => e.name == json['attractionCategory'],
            orElse: () => AttractionCategory.sightsAndLandmarks,
          )
        : null;
    final sightCategory = json['sightCategory'] != null
        ? SightCategory.values.firstWhere(
            (e) => e.name == json['sightCategory'],
            orElse: () => SightCategory.landmark,
          )
        : null;
    final serviceCategory = json['serviceCategory'] != null
        ? ServiceCategory.values.firstWhere(
            (e) => e.name == json['serviceCategory'],
            orElse: () => ServiceCategory.gear,
          )
        : null;
    final estimatedPriceRange = json['estimatedPriceRange'] != null
        ? PriceRange.fromJson(json['estimatedPriceRange'] as Map<String, dynamic>)
        : null;
    final photoUrlsRaw = (json['photoUrls'] as List<dynamic>?)?.cast<String>();
    final photoUrls = (photoUrlsRaw != null && photoUrlsRaw.isNotEmpty)
        ? photoUrlsRaw
        : (json['photoUrl'] != null ? [json['photoUrl'] as String] : null);
    final estimatedPrice = (json['estimatedPrice'] as num?)?.toDouble() ??
        (estimatedPriceRange != null
            ? (estimatedPriceRange.min + estimatedPriceRange.max) / 2
            : null);
    final subCategoryTagsRaw = (json['subCategoryTags'] as List<dynamic>?)?.cast<String>();
    final subCategoryTags = (subCategoryTagsRaw != null && subCategoryTagsRaw.isNotEmpty)
        ? subCategoryTagsRaw
        : subCategoryTagsFromTypedFields(
            accommodationType: accommodationType,
            eatCategory: eatCategory,
            attractionCategory: attractionCategory,
            sightCategory: sightCategory,
            serviceCategory: serviceCategory,
          );
    return RouteWaypoint(
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
        photoUrls: photoUrls,
        rating: (json['rating'] as num?)?.toDouble(),
        website: json['website'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        address: json['address'] as String?,
        accommodationType: accommodationType,
        amadeusPropertyId: json['amadeusPropertyId'] as String?,
        amenities: (json['amenities'] as List?)?.cast<String>(),
        hotelChain: json['hotelChain'] as String?,
        estimatedPriceRange: estimatedPriceRange,
        estimatedPrice: estimatedPrice,
        subCategoryTags: subCategoryTags.isEmpty ? null : subCategoryTags,
        bookingComUrl: json['bookingComUrl'] as String?,
        airbnbPropertyUrl: json['airbnbPropertyUrl'] as String?,
        airbnbPropertyId: json['airbnbPropertyId'] as String?,
        eatCategory: eatCategory,
        mealTime: json['mealTime'] != null
            ? MealTime.values.firstWhere(
                (e) => e.name == json['mealTime'],
                orElse: () => MealTime.lunch,
              )
            : null,
        attractionCategory: attractionCategory,
        activityTime: json['activityTime'] != null
            ? ActivityTime.values.firstWhere(
                (e) => e.name == json['activityTime'],
                orElse: () => ActivityTime.allDay,
              )
            : null,
        sightCategory: sightCategory,
        serviceCategory: serviceCategory,
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
        waypointSnapInfo: json['waypointSnapInfo'] != null
            ? WaypointSnapInfo.fromJson(json['waypointSnapInfo'] as Map<String, dynamic>)
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
  }

  RouteWaypoint copyWith({
    String? id,
    WaypointType? type,
    ll.LatLng? position,
    String? name,
    String? description,
    int? order,
    String? googlePlaceId,
    String? photoUrl,
    List<String>? photoUrls,
    double? rating,
    String? website,
    String? phoneNumber,
    String? address,
    POIAccommodationType? accommodationType,
    String? amadeusPropertyId,
    List<String>? amenities,
    String? hotelChain,
    PriceRange? estimatedPriceRange,
    double? estimatedPrice,
    List<String>? subCategoryTags,
    String? bookingComUrl,
    String? airbnbPropertyUrl,
    String? airbnbPropertyId,
    Object? eatCategory = _clear,
    MealTime? mealTime,
    Object? attractionCategory = _clear,
    ActivityTime? activityTime,
    Object? sightCategory = _clear,
    ServiceCategory? serviceCategory,
    LogisticsCategory? logisticsCategory,
    String? travelMode,
    int? travelTime,
    double? travelDistance,
    List<ll.LatLng>? travelRouteGeometry,
    WaypointSnapInfo? waypointSnapInfo,
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
        photoUrls: photoUrls ?? this.photoUrls,
        rating: rating ?? this.rating,
        website: website ?? this.website,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        address: address ?? this.address,
        accommodationType: accommodationType ?? this.accommodationType,
        amadeusPropertyId: amadeusPropertyId ?? this.amadeusPropertyId,
        amenities: amenities ?? this.amenities,
        hotelChain: hotelChain ?? this.hotelChain,
        estimatedPriceRange: estimatedPriceRange ?? this.estimatedPriceRange,
        estimatedPrice: estimatedPrice ?? this.estimatedPrice,
        subCategoryTags: subCategoryTags ?? this.subCategoryTags,
        bookingComUrl: bookingComUrl ?? this.bookingComUrl,
        airbnbPropertyUrl: airbnbPropertyUrl ?? this.airbnbPropertyUrl,
        airbnbPropertyId: airbnbPropertyId ?? this.airbnbPropertyId,
        eatCategory: eatCategory == _clear ? this.eatCategory : eatCategory as EatCategory?,
        mealTime: mealTime ?? this.mealTime,
        attractionCategory: attractionCategory == _clear ? this.attractionCategory : attractionCategory as AttractionCategory?,
        activityTime: activityTime ?? this.activityTime,
        sightCategory: sightCategory == _clear ? this.sightCategory : sightCategory as SightCategory?,
        serviceCategory: serviceCategory ?? this.serviceCategory,
        logisticsCategory: logisticsCategory ?? this.logisticsCategory,
        travelMode: travelMode ?? this.travelMode,
        travelTime: travelTime ?? this.travelTime,
        travelDistance: travelDistance ?? this.travelDistance,
        travelRouteGeometry: travelRouteGeometry ?? this.travelRouteGeometry,
        waypointSnapInfo: waypointSnapInfo ?? this.waypointSnapInfo,
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
/// Sentinel for copyWith: pass _clear to explicitly set a nullable subcategory field to null.
const Object _clear = Object();

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
  // Map WaypointType enum to string for markerColor()
  // NOTE: This assumes enum values like WaypointType.viewingPoint produce 'viewingpoint'
  // (one word, no space). This holds for the current enum but is fragile if enum names change.
  // For long-term maintainability, consider an explicit Map<WaypointType, String> instead.
  final typeString = type.toString().split('.').last.toLowerCase();
  return WaypointIconColors.markerColor(typeString);
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

String getEatCategoryLabel(EatCategory? c) {
  if (c == null) return '';
  switch (c) {
    case EatCategory.diningRestaurant: return 'Dining restaurant';
    case EatCategory.cafe: return 'Cafe';
    case EatCategory.bar: return 'Bar';
    case EatCategory.quickBite: return 'Quick bite';
    case EatCategory.bakery: return 'Bakery';
  }
}

String getAttractionCategoryLabel(AttractionCategory? c) {
  if (c == null) return '';
  switch (c) {
    case AttractionCategory.sightsAndLandmarks: return 'Sights & landmarks';
    case AttractionCategory.museumsAndCulture: return 'Museums & culture';
    case AttractionCategory.natureAndOutdoors: return 'Nature & outdoors';
    case AttractionCategory.toursAndExperiences: return 'Tours & experiences';
    case AttractionCategory.entertainment: return 'Entertainment';
    case AttractionCategory.nightlife: return 'Nightlife';
    case AttractionCategory.sportsAndActivities: return 'Sports & activities';
  }
}

String getSightCategoryLabel(SightCategory? c) {
  if (c == null) return '';
  switch (c) {
    case SightCategory.landmark: return 'Landmark';
    case SightCategory.viewpoint: return 'Viewpoint';
    case SightCategory.scenicSpot: return 'Scenic spot';
    case SightCategory.observationDeck: return 'Observation deck';
    case SightCategory.monument: return 'Monument';
  }
}

String getPOIAccommodationTypeLabel(POIAccommodationType? t) {
  if (t == null) return '';
  switch (t) {
    case POIAccommodationType.hotel: return 'Hotel';
    case POIAccommodationType.airbnb: return 'Airbnb';
    case POIAccommodationType.bedAndBreakfast: return 'Bed & breakfast';
    case POIAccommodationType.hostel: return 'Hostel';
    case POIAccommodationType.camping: return 'Camping';
    case POIAccommodationType.vacationRental: return 'Vacation rental';
  }
}

String getServiceCategoryLabel(ServiceCategory? c) {
  if (c == null) return '';
  switch (c) {
    case ServiceCategory.trainStation: return 'Train';
    case ServiceCategory.carRental: return 'Car';
    case ServiceCategory.bus: return 'Bus';
    case ServiceCategory.plane: return 'Plane';
    case ServiceCategory.bike: return 'Bike';
    case ServiceCategory.other: return 'Other';
    case ServiceCategory.gear: return 'Gear';
    case ServiceCategory.transportation: return 'Transport';
    case ServiceCategory.food: return 'Food';
  }
}

/// Derive subcategory tag labels from already-parsed typed fields (for fromJson when subCategoryTags is null/empty).
List<String> subCategoryTagsFromTypedFields({
  POIAccommodationType? accommodationType,
  EatCategory? eatCategory,
  AttractionCategory? attractionCategory,
  SightCategory? sightCategory,
  ServiceCategory? serviceCategory,
}) {
  final list = <String>[];
  final a = getPOIAccommodationTypeLabel(accommodationType);
  if (a.isNotEmpty) list.add(a);
  final e = getEatCategoryLabel(eatCategory);
  if (e.isNotEmpty) list.add(e);
  final at = getAttractionCategoryLabel(attractionCategory);
  if (at.isNotEmpty) list.add(at);
  final s = getSightCategoryLabel(sightCategory);
  if (s.isNotEmpty) list.add(s);
  final sv = getServiceCategoryLabel(serviceCategory);
  if (sv.isNotEmpty) list.add(sv);
  return list;
}

POIAccommodationType? accommodationTypeFromLabel(String label) {
  final t = label.trim();
  for (final e in POIAccommodationType.values) {
    if (getPOIAccommodationTypeLabel(e) == t) return e;
  }
  return null;
}

EatCategory? eatCategoryFromLabel(String label) {
  final t = label.trim();
  for (final e in EatCategory.values) {
    if (getEatCategoryLabel(e) == t) return e;
  }
  return null;
}

AttractionCategory? attractionCategoryFromLabel(String label) {
  final t = label.trim();
  for (final e in AttractionCategory.values) {
    if (getAttractionCategoryLabel(e) == t) return e;
  }
  return null;
}

SightCategory? sightCategoryFromLabel(String label) {
  final t = label.trim();
  for (final e in SightCategory.values) {
    if (getSightCategoryLabel(e) == t) return e;
  }
  return null;
}

ServiceCategory? serviceCategoryFromLabel(String label) {
  final t = label.trim();
  for (final e in ServiceCategory.values) {
    if (getServiceCategoryLabel(e) == t) return e;
  }
  return null;
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

