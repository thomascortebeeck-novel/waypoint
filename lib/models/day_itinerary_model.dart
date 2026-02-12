import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/route_info_model.dart';

/// Full day itinerary data stored in subcollection
/// Stored in: plans/{planId}/versions/{versionId}/days/{dayNum}
class DayItineraryDoc {
  final String id; // Document ID (typically 'day_1', 'day_2', etc.)
  final String planId;
  final String versionId;
  final int dayNum;
  final String title;
  final String description;
  final double distanceKm;
  final int estimatedTimeMinutes;
  final StayInfo? stay;
  final List<AccommodationInfo> accommodations;
  final List<RestaurantInfo> restaurants;
  final List<ActivityInfo> activities;
  final List<String> photos;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final DayRoute? route;
  final String? komootLink;
  final String? allTrailsLink;
  final RouteInfo? routeInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  DayItineraryDoc({
    required this.id,
    required this.planId,
    required this.versionId,
    required this.dayNum,
    required this.title,
    required this.description,
    required this.distanceKm,
    required this.estimatedTimeMinutes,
    this.stay,
    this.accommodations = const [],
    this.restaurants = const [],
    this.activities = const [],
    this.photos = const [],
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.route,
    this.komootLink,
    this.allTrailsLink,
    this.routeInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get estimatedTime => Duration(minutes: estimatedTimeMinutes);

  factory DayItineraryDoc.fromJson(Map<String, dynamic> json) => DayItineraryDoc(
    id: json['id'] as String,
    planId: json['plan_id'] as String,
    versionId: json['version_id'] as String,
    dayNum: json['day_num'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    distanceKm: (json['distance_km'] as num).toDouble(),
    estimatedTimeMinutes: json['estimated_time_minutes'] as int,
    stay: json['stay'] != null
        ? StayInfo.fromJson(json['stay'] as Map<String, dynamic>)
        : null,
    accommodations: (json['accommodations'] as List<dynamic>?)
        ?.map((a) => AccommodationInfo.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    restaurants: (json['restaurants'] as List<dynamic>?)
        ?.map((r) => RestaurantInfo.fromJson(r as Map<String, dynamic>))
        .toList() ?? [],
    activities: (json['activities'] as List<dynamic>?)
        ?.map((a) => ActivityInfo.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    photos: List<String>.from(json['photos'] ?? []),
    startLat: (json['start_lat'] as num?)?.toDouble(),
    startLng: (json['start_lng'] as num?)?.toDouble(),
    endLat: (json['end_lat'] as num?)?.toDouble(),
    endLng: (json['end_lng'] as num?)?.toDouble(),
    route: json['route'] != null
        ? DayRoute.fromJson(json['route'] as Map<String, dynamic>)
        : null,
    komootLink: json['komoot_link'] as String?,
    allTrailsLink: json['all_trails_link'] as String?,
    routeInfo: json['route_info'] != null
        ? RouteInfo.fromJson(json['route_info'] as Map<String, dynamic>)
        : null,
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'version_id': versionId,
    'day_num': dayNum,
    'title': title,
    'description': description,
    'distance_km': distanceKm,
    'estimated_time_minutes': estimatedTimeMinutes,
    if (stay != null) 'stay': stay!.toJson(),
    'accommodations': accommodations.map((a) => a.toJson()).toList(),
    'restaurants': restaurants.map((r) => r.toJson()).toList(),
    'activities': activities.map((a) => a.toJson()).toList(),
    'photos': photos,
    if (startLat != null) 'start_lat': startLat,
    if (startLng != null) 'start_lng': startLng,
    if (endLat != null) 'end_lat': endLat,
    if (endLng != null) 'end_lng': endLng,
    if (route != null) 'route': route!.toJson(),
    if (komootLink != null && komootLink!.isNotEmpty) 'komoot_link': komootLink,
    if (allTrailsLink != null && allTrailsLink!.isNotEmpty) 'all_trails_link': allTrailsLink,
    if (routeInfo != null) 'route_info': routeInfo!.toJson(),
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  DayItineraryDoc copyWith({
    String? id,
    String? planId,
    String? versionId,
    int? dayNum,
    String? title,
    String? description,
    double? distanceKm,
    int? estimatedTimeMinutes,
    StayInfo? stay,
    List<AccommodationInfo>? accommodations,
    List<RestaurantInfo>? restaurants,
    List<ActivityInfo>? activities,
    List<String>? photos,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    DayRoute? route,
    String? komootLink,
    String? allTrailsLink,
    RouteInfo? routeInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DayItineraryDoc(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    versionId: versionId ?? this.versionId,
    dayNum: dayNum ?? this.dayNum,
    title: title ?? this.title,
    description: description ?? this.description,
    distanceKm: distanceKm ?? this.distanceKm,
    estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
    stay: stay ?? this.stay,
    accommodations: accommodations ?? this.accommodations,
    restaurants: restaurants ?? this.restaurants,
    activities: activities ?? this.activities,
    photos: photos ?? this.photos,
    startLat: startLat ?? this.startLat,
    startLng: startLng ?? this.startLng,
    endLat: endLat ?? this.endLat,
    endLng: endLng ?? this.endLng,
    route: route ?? this.route,
    komootLink: komootLink ?? this.komootLink,
    allTrailsLink: allTrailsLink ?? this.allTrailsLink,
    routeInfo: routeInfo ?? this.routeInfo,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Convert from legacy DayItinerary (for migration)
  factory DayItineraryDoc.fromDayItinerary(
    DayItinerary day,
    String planId,
    String versionId,
  ) => DayItineraryDoc(
    id: 'day_${day.dayNum}',
    planId: planId,
    versionId: versionId,
    dayNum: day.dayNum,
    title: day.title,
    description: day.description,
    distanceKm: day.distanceKm,
    estimatedTimeMinutes: day.estimatedTimeMinutes,
    stay: day.stay,
    accommodations: day.accommodations,
    restaurants: day.restaurants,
    activities: day.activities,
    photos: day.photos,
    startLat: day.startLat,
    startLng: day.startLng,
    endLat: day.endLat,
    endLng: day.endLng,
    route: day.route,
    komootLink: day.komootLink,
    allTrailsLink: day.allTrailsLink,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// Convert to legacy DayItinerary (for backwards compatibility)
  DayItinerary toDayItinerary() => DayItinerary(
    dayNum: dayNum,
    title: title,
    description: description,
    distanceKm: distanceKm,
    estimatedTimeMinutes: estimatedTimeMinutes,
    stay: stay,
    accommodations: accommodations,
    restaurants: restaurants,
    activities: activities,
    photos: photos,
    startLat: startLat,
    startLng: startLng,
    endLat: endLat,
    endLng: endLng,
    route: route,
    komootLink: komootLink,
    allTrailsLink: allTrailsLink,
  );
}

/// POI Waypoint stored in subcollection
/// Stored in: plans/{planId}/versions/{versionId}/days/{dayNum}/waypoints/{waypointId}
class WaypointDoc {
  final String id;
  final String planId;
  final String versionId;
  final int dayNum;
  final RouteWaypoint waypoint;
  final DateTime createdAt;
  final DateTime updatedAt;

  WaypointDoc({
    required this.id,
    required this.planId,
    required this.versionId,
    required this.dayNum,
    required this.waypoint,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaypointDoc.fromJson(Map<String, dynamic> json) => WaypointDoc(
    id: json['id'] as String,
    planId: json['plan_id'] as String,
    versionId: json['version_id'] as String,
    dayNum: json['day_num'] as int,
    waypoint: RouteWaypoint.fromJson(json['waypoint'] as Map<String, dynamic>),
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'version_id': versionId,
    'day_num': dayNum,
    'waypoint': waypoint.toJson(),
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };
}
