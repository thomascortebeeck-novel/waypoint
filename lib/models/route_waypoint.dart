import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:uuid/uuid.dart';

/// Types of POI waypoints that can be added to a route
enum WaypointType {
  restaurant,
  accommodation,
  activity,
  viewingPoint,
}

/// Accommodation sub-type
enum AccommodationType {
  hotel,
  airbnb,
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
  AccommodationType? accommodationType; // Only for accommodation type
  String? amadeusPropertyId; // Will be used in Phase 3 for hotels
  List<String>? amenities;
  String? hotelChain;
  PriceRange? estimatedPriceRange;
  String? bookingComUrl;
  String? airbnbPropertyUrl;
  String? airbnbPropertyId;

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
            ? AccommodationType.values.firstWhere(
                (e) => e.name == json['accommodationType'],
                orElse: () => AccommodationType.hotel,
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
    AccommodationType? accommodationType,
    String? amadeusPropertyId,
    List<String>? amenities,
    String? hotelChain,
    PriceRange? estimatedPriceRange,
    String? bookingComUrl,
    String? airbnbPropertyUrl,
    String? airbnbPropertyId,
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
  }
}
