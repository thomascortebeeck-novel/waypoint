import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';

/// Types of POI waypoints that can be added to a route
enum WaypointType {
  restaurant,
  accommodation,
  activity,
  viewingPoint,
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
  ActivityTime? activityTime; // Only for activity type

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
      };

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) => RouteWaypoint(
        id: json['id'] as String,
        type: WaypointType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => WaypointType.activity,
        ),
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
      );
}

/// Get the icon for a waypoint type
IconData getWaypointIcon(WaypointType type) {
  switch (type) {
    case WaypointType.restaurant:
      return Icons.restaurant;
    case WaypointType.accommodation:
      return Icons.hotel;
    case WaypointType.activity:
      return Icons.local_activity;
    case WaypointType.viewingPoint:
      return Icons.visibility;
    case WaypointType.servicePoint:
      return Icons.local_convenience_store;
  }
}

/// Get the color for a waypoint type
Color getWaypointColor(WaypointType type) {
  switch (type) {
    case WaypointType.restaurant:
      return const Color(0xFFFF9800); // Orange
    case WaypointType.accommodation:
      return const Color(0xFF2196F3); // Blue
    case WaypointType.activity:
      return const Color(0xFF9C27B0); // Purple
    case WaypointType.viewingPoint:
      return const Color(0xFFFFC107); // Yellow/Gold
    case WaypointType.servicePoint:
      return const Color(0xFF4CAF50); // Green
  }
}

/// Get the display label for a waypoint type
String getWaypointLabel(WaypointType type) {
  switch (type) {
    case WaypointType.restaurant:
      return 'Restaurant';
    case WaypointType.accommodation:
      return 'Accommodation';
    case WaypointType.activity:
      return 'Activity';
    case WaypointType.viewingPoint:
      return 'Viewing Point';
    case WaypointType.servicePoint:
      return 'Service Point';
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
