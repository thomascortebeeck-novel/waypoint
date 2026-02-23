import 'package:flutter/material.dart';

/// Route information for a day - can be auto-calculated from waypoints or manually entered
enum RouteInfoSource {
  auto,   // Auto-calculated from Google Maps waypoints (roadTripping, cityTrips, tours)
  manual  // Manually entered by user (hiking, cycling, skis, climbing)
}

/// Distance unit preference
enum DistanceUnit {
  km,     // Kilometers
  miles,  // Miles
}

/// Elevation unit preference
enum ElevationUnit {
  meters, // Meters
  feet,   // Feet
}

/// Route metadata for a day
class RouteInfo {
  final double? distanceKm;        // Distance in kilometers (always stored in metric)
  final int? elevationM;           // Elevation gain in meters (always stored in metric)
  final String? estimatedTime;     // Estimated duration, format: "6h 30m"
  final String? difficulty;       // "easy", "moderate", or "hard" (only for manual entry)
  final int? numStops;             // Number of waypoints/stops (only for auto-calculated)
  final RouteInfoSource source;     // 'auto' or 'manual'
  final DistanceUnit? distanceUnit; // User's preferred distance unit for display/input
  final ElevationUnit? elevationUnit; // User's preferred elevation unit for display/input

  RouteInfo({
    this.distanceKm,
    this.elevationM,
    this.estimatedTime,
    this.difficulty,
    this.numStops,
    required this.source,
    this.distanceUnit,
    this.elevationUnit,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    try {
      // Parse source - handle both string and enum
      RouteInfoSource source;
      final sourceStr = json['source'] as String?;
      if (sourceStr == 'auto' || sourceStr == 'manual') {
        source = sourceStr == 'auto' ? RouteInfoSource.auto : RouteInfoSource.manual;
      } else {
        // Default to manual for backward compatibility with old scraped data
        source = RouteInfoSource.manual;
      }

      // Parse units (optional, defaults to metric)
      DistanceUnit? distanceUnit;
      final distanceUnitStr = json['distance_unit'] as String?;
      if (distanceUnitStr == 'km' || distanceUnitStr == 'miles') {
        distanceUnit = distanceUnitStr == 'km' ? DistanceUnit.km : DistanceUnit.miles;
      }

      ElevationUnit? elevationUnit;
      final elevationUnitStr = json['elevation_unit'] as String?;
      if (elevationUnitStr == 'meters' || elevationUnitStr == 'feet') {
        elevationUnit = elevationUnitStr == 'meters' ? ElevationUnit.meters : ElevationUnit.feet;
      }

      return RouteInfo(
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        elevationM: (json['elevation_m'] as num?)?.toInt(),
        estimatedTime: json['estimated_time'] as String? ?? json['estimatedTime'] as String?,
        difficulty: json['difficulty'] as String?,
        numStops: (json['num_stops'] as num?)?.toInt(),
        source: source,
        distanceUnit: distanceUnit,
        elevationUnit: elevationUnit,
      );
    } catch (e) {
      // Fallback for malformed data
      return RouteInfo(
        source: RouteInfoSource.manual,
      );
    }
  }

  Map<String, dynamic> toJson() => {
        if (distanceKm != null) 'distance_km': distanceKm,
        if (elevationM != null) 'elevation_m': elevationM,
        if (estimatedTime != null) 'estimated_time': estimatedTime,
        if (difficulty != null) 'difficulty': difficulty,
        if (numStops != null) 'num_stops': numStops,
        'source': source.name,
        if (distanceUnit != null) 'distance_unit': distanceUnit!.name,
        if (elevationUnit != null) 'elevation_unit': elevationUnit!.name,
      };

  RouteInfo copyWith({
    double? distanceKm,
    int? elevationM,
    String? estimatedTime,
    String? difficulty,
    int? numStops,
    RouteInfoSource? source,
    DistanceUnit? distanceUnit,
    ElevationUnit? elevationUnit,
  }) =>
      RouteInfo(
        distanceKm: distanceKm ?? this.distanceKm,
        elevationM: elevationM ?? this.elevationM,
        estimatedTime: estimatedTime ?? this.estimatedTime,
        difficulty: difficulty ?? this.difficulty,
        numStops: numStops ?? this.numStops,
        source: source ?? this.source,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        elevationUnit: elevationUnit ?? this.elevationUnit,
      );

  /// Get difficulty color for UI
  Color get difficultyColor {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
