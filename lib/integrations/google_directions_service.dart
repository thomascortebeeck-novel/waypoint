import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/utils/logger.dart';

/// 🔒 SECURE Google Directions Service using Firebase Cloud Functions
/// All API calls are proxied through backend to protect API keys and implement rate limiting
class GoogleDirectionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // 📦 Cache for route results (reduces redundant API calls)
  final Map<String, RouteResult> _routeCache = {};
  
  // 🔄 Prevent duplicate simultaneous requests
  final Map<String, Future<RouteResult?>> _inflightRoutes = {};

  /// Calculate route between waypoints using Google Directions API
  /// Returns route with geometry, distance, and duration
  Future<RouteResult?> getRoute({
    required List<ll.LatLng> waypoints,
    TravelMode travelMode = TravelMode.driving,
    bool optimizeWaypoints = false,
  }) async {
    if (waypoints.length < 2) {
      Log.w('google_directions', '⚠️ Need at least 2 waypoints');
      return null;
    }

    // Create cache key
    final cacheKey = _getCacheKey(waypoints, travelMode, optimizeWaypoints);
    
    // Check cache first
    if (_routeCache.containsKey(cacheKey)) {
      Log.i('google_directions', '📦 Cache hit for route');
      return _routeCache[cacheKey];
    }

    // Deduplicate simultaneous requests
    if (_inflightRoutes.containsKey(cacheKey)) {
      Log.i('google_directions', '🔄 Waiting for in-flight route request');
      return _inflightRoutes[cacheKey];
    }

    final routeFuture = _performRouteRequest(
      waypoints: waypoints,
      travelMode: travelMode,
      optimizeWaypoints: optimizeWaypoints,
    );
    
    _inflightRoutes[cacheKey] = routeFuture;

    try {
      final result = await routeFuture;
      if (result != null) {
        _routeCache[cacheKey] = result;
        
        // Cache cleanup (keep last 50 routes)
        if (_routeCache.length > 50) {
          _routeCache.remove(_routeCache.keys.first);
        }
      }
      return result;
    } finally {
      _inflightRoutes.remove(cacheKey);
    }
  }

  String _getCacheKey(List<ll.LatLng> waypoints, TravelMode travelMode, bool optimizeWaypoints) {
    final waypointStr = waypoints.map((w) => '${w.latitude},${w.longitude}').join('|');
    return '$waypointStr|${travelMode.name}|$optimizeWaypoints';
  }

  Future<RouteResult?> _performRouteRequest({
    required List<ll.LatLng> waypoints,
    required TravelMode travelMode,
    required bool optimizeWaypoints,
  }) async {
    try {
      Log.i('google_directions', '🗺️ Calculating route with ${waypoints.length} waypoints, mode: ${travelMode.name}');

      final result = await _functions.httpsCallable('googleDirections').call({
        'waypoints': waypoints.map((w) => {
          'lat': w.latitude,
          'lng': w.longitude,
        }).toList(),
        'travelMode': travelMode.name,
        'optimizeWaypoints': optimizeWaypoints,
      });

      if (result.data == null) {
        // ZERO_RESULTS or other cases where no route is found
        Log.w('google_directions', '⚠️ No route found between waypoints (ZERO_RESULTS or null response)');
        return null;
      }

      final route = RouteResult.fromJson(result.data as Map<String, dynamic>);
      Log.i('google_directions', '✅ Route calculated: ${route.distanceKm.toStringAsFixed(2)}km, ${route.durationMinutes}min');
      return route;
    } on FirebaseFunctionsException catch (e) {
      // Check if this is a ZERO_RESULTS case (handled gracefully on backend)
      if (e.message != null && e.message!.contains('ZERO_RESULTS')) {
        Log.w('google_directions', '⚠️ No route found between waypoints');
        return null;
      }

      Log.e('google_directions', '❌ Route calculation failed: ${e.code} - ${e.message}', e);

      if (e.code == 'resource-exhausted') {
        throw Exception('Too many route requests. Please wait a moment and try again.');
      }

      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to calculate routes.');
      }

      return null;
    } catch (e, stack) {
      Log.e('google_directions', '❌ Unexpected error', e, stack);
      return null;
    }
  }
}

/// Travel mode for route calculation
enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}

/// Route result from Google Directions API
class RouteResult {
  final List<ll.LatLng> geometry; // Polyline points
  final double distanceMeters; // Distance in meters
  final int durationSeconds; // Duration in seconds
  final String? polyline; // Encoded polyline string (if available)

  RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    this.polyline,
  });

  /// Distance in kilometers
  double get distanceKm => distanceMeters / 1000.0;

  /// Duration in minutes
  int get durationMinutes => (durationSeconds / 60).round();

  /// Duration as formatted string (e.g., "2h 30m" or "45m")
  String get durationFormatted {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    // Parse geometry from coordinates array
    final coordinates = json['geometry'] as List<dynamic>? ?? [];
    final geometry = coordinates.map((coord) {
      if (coord is List && coord.length >= 2) {
        return ll.LatLng(
          (coord[1] as num).toDouble(), // lat
          (coord[0] as num).toDouble(), // lng
        );
      }
      return null;
    }).whereType<ll.LatLng>().toList();

    return RouteResult(
      geometry: geometry,
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      polyline: json['polyline'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'geometry': geometry.map((p) => [p.longitude, p.latitude]).toList(),
        'distance': distanceMeters,
        'duration': durationSeconds,
        if (polyline != null) 'polyline': polyline,
      };
}

