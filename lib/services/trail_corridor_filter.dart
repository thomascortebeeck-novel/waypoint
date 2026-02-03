import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/models/poi_model.dart';

/// High-performance filter to find POIs within a specified radius of a trail polyline.
/// 
/// Uses a two-stage optimization:
/// 1. Bounding Box (AABB) check to quickly discard POIs far from the trail
/// 2. Per-segment distance calculation using Haversine formula for accurate filtering
/// 
/// Designed to be run on a background isolate using `compute()` to avoid UI jank.
class TrailCorridorFilter {
  /// Filter POIs that are within [radiusMeters] of any point on the [trail] polyline.
  /// 
  /// [trail] - List of LatLng points representing the trail/polyline
  /// [pois] - List of POI objects to filter
  /// [radiusMeters] - Maximum distance in meters from the trail (default: 2000m)
  /// 
  /// Returns a filtered list of POIs within the corridor.
  static List<POI> filterPOIsInCorridor({
    required List<LatLng> trail,
    required List<POI> pois,
    double radiusMeters = 2000.0,
  }) {
    if (trail.isEmpty || pois.isEmpty) {
      return [];
    }

    // Convert radius from meters to kilometers for Haversine calculation
    final radiusKm = radiusMeters / 1000.0;

    // Stage 1: Calculate bounding box of trail (AABB optimization)
    final trailBounds = _calculateBoundingBox(trail);
    
    // Expand bounding box by radius to create a "corridor box"
    final expandedBounds = _expandBounds(trailBounds, radiusKm);

    // Stage 2: Filter POIs using two-stage approach
    final filteredPOIs = <POI>[];

    for (final poi in pois) {
      // Quick rejection: Check if POI is within expanded bounding box
      if (!_isPointInBounds(poi.coordinates, expandedBounds)) {
        continue; // POI is definitely outside the corridor
      }

      // Accurate check: Calculate minimum distance from POI to trail segments
      final minDistance = _calculateMinDistanceToTrail(poi.coordinates, trail);

      if (minDistance <= radiusKm) {
        filteredPOIs.add(poi);
      }
    }

    return filteredPOIs;
  }

  /// Filter POIs in a background isolate to prevent UI jank.
  /// 
  /// Use this method when filtering large numbers of POIs against long trails.
  /// 
  /// Example:
  /// ```dart
  /// final filteredPOIs = await TrailCorridorFilter.filterPOIsInCorridorAsync(
  ///   trail: routePoints,
  ///   pois: allPOIs,
  ///   radiusMeters: 2000.0,
  /// );
  /// ```
  static Future<List<POI>> filterPOIsInCorridorAsync({
    required List<LatLng> trail,
    required List<POI> pois,
    double radiusMeters = 2000.0,
  }) async {
    if (trail.isEmpty || pois.isEmpty) {
      return [];
    }

    // Convert to primitive types for isolate serialization
    // LatLng objects don't serialize across isolate boundaries
    final trailData = trail.map((p) => [p.latitude, p.longitude]).toList();
    final poisJson = pois.map((poi) => poi.toJson()).toList();

    final params = _FilterParams(
      trailData: trailData,
      poisJson: poisJson,
      radiusMeters: radiusMeters,
    );

    // Run filtering in background isolate
    final filteredPOIs = await compute(_filterPOIsInBackground, params);

    return filteredPOIs;
  }

  /// Calculate the axis-aligned bounding box (AABB) of a trail polyline.
  static _TrailBounds _calculateBoundingBox(List<LatLng> trail) {
    if (trail.isEmpty) {
      throw ArgumentError('Trail cannot be empty');
    }

    double minLat = trail[0].latitude;
    double maxLat = trail[0].latitude;
    double minLng = trail[0].longitude;
    double maxLng = trail[0].longitude;

    for (final point in trail) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return _TrailBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  /// Expand bounding box by a specified radius (in kilometers).
  static _TrailBounds _expandBounds(_TrailBounds bounds, double radiusKm) {
    // Approximate: 1 degree latitude ≈ 111 km
    // Longitude varies by latitude, but we'll use a conservative estimate
    final latExpansion = radiusKm / 111.0;
    final lngExpansion = radiusKm / (111.0 * math.cos(bounds.centerLat * math.pi / 180.0));

    return _TrailBounds(
      minLat: bounds.minLat - latExpansion,
      maxLat: bounds.maxLat + latExpansion,
      minLng: bounds.minLng - lngExpansion,
      maxLng: bounds.maxLng + lngExpansion,
    );
  }

  /// Check if a point is within the given bounds.
  static bool _isPointInBounds(LatLng point, _TrailBounds bounds) {
    return point.latitude >= bounds.minLat &&
           point.latitude <= bounds.maxLat &&
           point.longitude >= bounds.minLng &&
           point.longitude <= bounds.maxLng;
  }

  /// Calculate the minimum distance from a point to any segment of the trail.
  /// 
  /// Uses the Haversine formula for accurate distance calculation.
  /// Returns distance in kilometers.
  static double _calculateMinDistanceToTrail(LatLng point, List<LatLng> trail) {
    if (trail.length < 2) {
      // Single point trail - just calculate distance to that point
      return _haversineDistance(point, trail[0]);
    }

    double minDistance = double.infinity;

    // Check distance to each segment of the trail
    for (int i = 0; i < trail.length - 1; i++) {
      final segmentStart = trail[i];
      final segmentEnd = trail[i + 1];

      // Calculate distance from point to line segment
      final distance = _distanceToSegment(point, segmentStart, segmentEnd);
      minDistance = math.min(minDistance, distance);
    }

    return minDistance;
  }

  /// Calculate the distance from a point to a line segment.
  /// 
  /// Uses the cross-track distance formula for accurate perpendicular distance.
  /// Returns distance in kilometers.
  static double _distanceToSegment(LatLng point, LatLng segmentStart, LatLng segmentEnd) {
    // Calculate distances
    final distToStart = _haversineDistance(point, segmentStart);
    final distToEnd = _haversineDistance(point, segmentEnd);
    final segmentLength = _haversineDistance(segmentStart, segmentEnd);

    // If segment is degenerate (start == end), return distance to point
    if (segmentLength < 0.0001) {
      return distToStart;
    }

    // Calculate bearing from start to end
    final bearing = _bearing(segmentStart, segmentEnd);
    
    // Calculate bearing from start to point
    final bearingToPoint = _bearing(segmentStart, point);

    // Calculate cross-track distance (perpendicular distance to segment)
    // Using angular distance formula to avoid precision issues
    final angularDist = distToStart / 6371.0; // Angular distance in radians
    final bearingDiff = (bearingToPoint - bearing) * math.pi / 180.0;
    
    final crossTrackDistance = math.asin(
      math.sin(angularDist) * math.sin(bearingDiff)
    ).abs() * 6371.0;

    // Check if the perpendicular point is within the segment
    // Calculate along-track distance
    final cosAngularDist = math.cos(angularDist);
    final cosCrossTrack = math.cos(crossTrackDistance / 6371.0);
    
    // Clamp to avoid NaN from floating point errors
    // This prevents acos() from receiving values outside [-1, 1]
    final cosRatio = (cosAngularDist / cosCrossTrack).clamp(-1.0, 1.0);
    final alongTrackDistance = math.acos(cosRatio) * 6371.0;

    if (alongTrackDistance < 0 || alongTrackDistance > segmentLength) {
      // Perpendicular point is outside segment - return distance to nearest endpoint
      return math.min(distToStart, distToEnd);
    }

    // Perpendicular point is within segment - return cross-track distance
    return crossTrackDistance;
  }

  /// Calculate the distance between two points using the Haversine formula.
  /// 
  /// Returns distance in kilometers.
  static double _haversineDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    final lat1Rad = point1.latitude * math.pi / 180.0;
    final lat2Rad = point2.latitude * math.pi / 180.0;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180.0;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180.0;

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calculate the bearing (direction) from point1 to point2.
  /// 
  /// Returns bearing in degrees (0-360).
  static double _bearing(LatLng point1, LatLng point2) {
    final lat1Rad = point1.latitude * math.pi / 180.0;
    final lat2Rad = point2.latitude * math.pi / 180.0;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180.0;

    final y = math.sin(deltaLngRad) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLngRad);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = (bearingRad * 180.0 / math.pi + 360.0) % 360.0;

    return bearingDeg;
  }
}

/// Internal class to represent trail bounding box.
class _TrailBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  _TrailBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  double get centerLat => (minLat + maxLat) / 2.0;
  double get centerLng => (minLng + maxLng) / 2.0;
}

/// Data class for passing filter parameters to background isolate.
/// Uses primitive types only for proper serialization across isolate boundaries.
@immutable
class _FilterParams {
  /// Trail as List of [lat, lng] pairs (primitive doubles for serialization)
  final List<List<double>> trailData;
  
  /// POIs as JSON maps (serializable)
  final List<Map<String, dynamic>> poisJson;
  
  /// Corridor radius in meters
  final double radiusMeters;

  const _FilterParams({
    required this.trailData,
    required this.poisJson,
    required this.radiusMeters,
  });
}

/// Background isolate function for filtering POIs.
/// 
/// This function is designed to be called via `compute()` to avoid blocking the UI thread.
/// Must be a top-level function for `compute()` to work.
List<POI> _filterPOIsInBackground(_FilterParams params) {
  // Reconstruct LatLng objects from primitive data
  final trail = params.trailData
      .map((coords) => LatLng(coords[0], coords[1]))
      .toList();
  
  // Reconstruct POI objects from JSON
  final pois = params.poisJson.map((json) => POI.fromJson(json)).toList();

  return TrailCorridorFilter.filterPOIsInCorridor(
    trail: trail,
    pois: pois,
    radiusMeters: params.radiusMeters,
  );
}
