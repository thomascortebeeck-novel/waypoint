import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/services/trail_corridor_filter.dart';
import 'package:waypoint/utils/logger.dart';

/// Service for fetching outdoor Points of Interest from OpenStreetMap
class POIService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Fetch POIs within a bounding box
  /// 
  /// [southWest] and [northEast] define the search area
  /// [poiTypes] specifies which POI categories to fetch
  /// [maxResults] limits the number of results (default 500)
  /// 
  /// Returns a list of POI objects or empty list on error
  static Future<List<POI>> fetchPOIs({
    required LatLng southWest,
    required LatLng northEast,
    required List<POIType> poiTypes,
    int maxResults = 500,
  }) async {
    if (poiTypes.isEmpty) return [];

    try {
      Log.i('poi', 'Fetching POIs: types=${poiTypes.map((t) => t.name).toList()}, '
          'bounds=${southWest.latitude.toStringAsFixed(3)},${southWest.longitude.toStringAsFixed(3)} '
          'to ${northEast.latitude.toStringAsFixed(3)},${northEast.longitude.toStringAsFixed(3)}');

      final result = await _functions.httpsCallable('getOutdoorPOIs').call({
        'bounds': {
          'south': southWest.latitude,
          'west': southWest.longitude,
          'north': northEast.latitude,
          'east': northEast.longitude,
        },
        'poiTypes': poiTypes.map((t) => t.name).toList(),
        'maxResults': maxResults,
      });

      final data = result.data as Map<String, dynamic>;

      // Check for errors
      if (data['error'] != null) {
        final error = data['error'] as String;
        Log.w('poi', 'POI fetch error: $error');
        
        // Return empty list for known errors
        if (error == 'bounds_too_large') {
          Log.w('poi', 'Bounds too large - zoom in to see POIs');
        } else if (error == 'rate_limited') {
          Log.w('poi', 'Rate limited by Overpass API - try again in a moment');
        } else if (error == 'timeout') {
          Log.w('poi', 'Request timeout - try a smaller area');
        }
        
        return [];
      }

      // Parse features
      final features = (data['features'] as List?) ?? [];
      if (features.isEmpty) {
        Log.i('poi', 'No POIs found in this area');
        return [];
      }

      final pois = features
          .map((f) {
            try {
              return POI.fromJson(f as Map<String, dynamic>);
            } catch (e) {
              Log.w('poi', 'Failed to parse POI: $e');
              return null;
            }
          })
          .whereType<POI>()
          .toList();

      Log.i('poi', 'Fetched ${pois.length} POIs successfully');
      return pois;
    } catch (e, stack) {
      Log.e('poi', 'Failed to fetch POIs: $e');
      Log.e('poi', 'Stack trace: $stack');
      // Check if it's a FirebaseFunctionsException
      if (e is FirebaseFunctionsException) {
        Log.e('poi', 'Firebase Functions error: code=${e.code}, message=${e.message}, details=${e.details}');
      }
      return [];
    }
  }

  /// Fetch POIs near a center point with a radius in kilometers
  /// 
  /// This is a convenience method that converts radius to bounding box
  static Future<List<POI>> fetchPOIsNear({
    required LatLng center,
    required double radiusKm,
    required List<POIType> poiTypes,
    int maxResults = 500,
  }) async {
    // Convert radius to approximate lat/lng degrees
    // 1 degree latitude ≈ 111km
    // 1 degree longitude varies by latitude
    final latDegrees = radiusKm / 111.0;
    final lngDegrees = radiusKm / (111.0 * cos(center.latitude * pi / 180));

    final southWest = LatLng(
      center.latitude - latDegrees,
      center.longitude - lngDegrees,
    );
    final northEast = LatLng(
      center.latitude + latDegrees,
      center.longitude + lngDegrees,
    );

    return fetchPOIs(
      southWest: southWest,
      northEast: northEast,
      poiTypes: poiTypes,
      maxResults: maxResults,
    );
  }

  /// Filter POIs to only show those within a specified radius of a trail/route.
  /// 
  /// This is useful for the Route Builder screen where you want to show only
  /// POIs relevant to the route being built (like AllTrails does).
  /// 
  /// [trail] - List of LatLng points representing the route/trail polyline
  /// [pois] - List of POIs to filter (typically from fetchPOIs)
  /// [radiusMeters] - Maximum distance in meters from the trail (default: 2000m)
  /// [useBackgroundIsolate] - If true, runs filtering in background isolate (recommended for large datasets)
  /// 
  /// Returns a filtered list of POIs within the corridor.
  /// 
  /// Example:
  /// ```dart
  /// final allPOIs = await POIService.fetchPOIs(...);
  /// final routePoints = day.route.routePoints.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
  /// final nearbyPOIs = await POIService.filterPOIsNearTrail(
  ///   trail: routePoints,
  ///   pois: allPOIs,
  ///   radiusMeters: 2000.0,
  /// );
  /// ```
  static Future<List<POI>> filterPOIsNearTrail({
    required List<LatLng> trail,
    required List<POI> pois,
    double radiusMeters = 2000.0,
    bool useBackgroundIsolate = true,
  }) async {
    if (trail.isEmpty || pois.isEmpty) {
      return [];
    }

    Log.i('poi', 'Filtering ${pois.length} POIs for trail with ${trail.length} points (radius: ${radiusMeters}m)');

    if (useBackgroundIsolate && (trail.length > 100 || pois.length > 50)) {
      // Use background isolate for large datasets to prevent UI jank
      return await TrailCorridorFilter.filterPOIsInCorridorAsync(
        trail: trail,
        pois: pois,
        radiusMeters: radiusMeters,
      );
    } else {
      // Small datasets can run synchronously on main thread
      return TrailCorridorFilter.filterPOIsInCorridor(
        trail: trail,
        pois: pois,
        radiusMeters: radiusMeters,
      );
    }
  }
}
