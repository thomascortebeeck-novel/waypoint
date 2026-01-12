import 'dart:convert';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/utils/logger.dart';

/// Lightweight Mapbox API helper for geocoding and, later, directions/tiles.
class MapboxService {
  static final MapboxService _instance = MapboxService._internal();
  factory MapboxService() => _instance;
  MapboxService._internal();

  /// Query forward geocoding for place suggestions (places + POIs).
  /// Returns top [limit] results. Works on web and mobile.
  /// Optional [proximityLat]/[proximityLng] will bias results near a point.
  /// Optional [countries] can limit to specific country codes (e.g., 'se,no,fi').
  /// If [countries] is null or empty, search is worldwide.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    int limit = 6,
    double? proximityLat,
    double? proximityLng,
    String? countries, // Optional: 'se,no,fi' for Nordic, null for worldwide
  }) async {
    if (query.trim().isEmpty || !hasValidMapboxToken) return [];
    // We perform two passes to improve recall for names with diacritics (e.g., Ábeskojávri / Abiskojaure)
    final queries = <String>{query.trim()};
    final normalized = _removeDiacritics(query.trim());
    if (normalized.toLowerCase() != query.trim().toLowerCase()) queries.add(normalized);

    final results = <String, PlaceSuggestion>{};
    for (final q in queries) {
      final buf = StringBuffer(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json'
        // Include POIs and administrative units; enable fuzzy and multiple languages
        '?autocomplete=true&fuzzyMatch=true&types=place,region,country,poi,locality,neighborhood,poi.landmark&limit=$limit'
        '&language=sv,en,nb,fi',
      );
      if (proximityLat != null && proximityLng != null) {
        // Mapbox expects proximity as lng,lat
        buf.write('&proximity=${proximityLng.toStringAsFixed(6)},${proximityLat.toStringAsFixed(6)}');
      }
      // Only add country filter if specified (allows worldwide search when null)
      if (countries != null && countries.isNotEmpty) {
        buf.write('&country=$countries');
      }
      buf.write('&access_token=$mapboxPublicToken');
      final url = Uri.parse(buf.toString());
      try {
        final sw = Stopwatch()..start();
        Log.i('mapbox.search', 'GET ${url.path}?${url.query.replaceAll(RegExp('access_token=[^&]+'), 'access_token=***')}, proximity=$proximityLat,$proximityLng');
        final res = await http.get(url);
        if (res.statusCode != 200) {
          Log.w('mapbox.search', 'HTTP ${res.statusCode} (${sw.elapsedMilliseconds}ms) body=${res.body.substring(0, res.body.length.clamp(0, 200))}');
          continue;
        }
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>? ?? []);
        for (final f in features) {
          final s = PlaceSuggestion.fromGeoJSON(f as Map<String, dynamic>);
          results[s.id] = s; // dedupe by id
        }
        Log.i('mapbox.search', 'OK ${features.length} results (${sw.elapsedMilliseconds}ms)');
      } catch (e) {
        Log.e('mapbox.search', 'Exception for "$q"', e);
      }
    }
    return results.values.toList();
  }

  /// Calculate walking distance using Mapbox Directions API between two points in KM.
  /// Returns null if the request fails.
  Future<double?> walkingDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (!hasValidMapboxToken) return null;
    try {
      final sw = Stopwatch()..start();
      final coordStr = '${startLng.toStringAsFixed(6)},${startLat.toStringAsFixed(6)};${endLng.toStringAsFixed(6)},${endLat.toStringAsFixed(6)}';
      final url = Uri.parse('https://api.mapbox.com/directions/v5/mapbox/walking/$coordStr?alternatives=false&geometries=geojson&overview=simplified&access_token=$mapboxPublicToken');
      Log.i('mapbox.directions', 'GET ${url.path}?alternatives=false&geometries=geojson&overview=simplified&access_token=***');
      final res = await http.get(url);
      if (res.statusCode != 200) {
        Log.w('mapbox.directions', 'HTTP ${res.statusCode} (${sw.elapsedMilliseconds}ms) body=${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return null;
      }
      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final routes = (data['routes'] as List?) ?? const [];
      if (routes.isEmpty) return null;
      final meters = (routes.first['distance'] as num?)?.toDouble();
      if (meters == null) return null;
      final km = meters / 1000.0;
      Log.i('mapbox.directions', 'OK distance=${km.toStringAsFixed(2)}km (${sw.elapsedMilliseconds}ms)');
      return km;
    } catch (e) {
      Log.e('mapbox.directions', 'Exception', e);
      return null;
    }
  }

  /// Proxy Directions API via Cloud Functions (europe-west1).
  /// Returns a map with { geometry, distance, duration } or null on failure.
  Future<Map<String, dynamic>?> directions({
    required List<ll.LatLng> waypoints,
    String profile = 'walking',
  }) async {
    if (waypoints.length < 2) return null;
    try {
      final sw = Stopwatch()..start();
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('getDirections');
      Log.i('mapbox.cf', 'Calling getDirections with ${waypoints.length} waypoints');
      final resp = await callable.call({
        'waypoints': waypoints.map((w) => {'lat': w.latitude, 'lng': w.longitude}).toList(),
        'profile': profile,
      });
      final data = Map<String, dynamic>.from(resp.data as Map);
      if (data['geometry'] == null) return null;
      Log.i('mapbox.cf', 'getDirections OK (${sw.elapsedMilliseconds}ms)');
      return data;
    } catch (e) {
      Log.e('mapbox.cf', 'getDirections failed', e);
      return null;
    }
  }

  /// Proxy Map Matching API via Cloud Functions (europe-west1).
  /// Returns a map with { geometry, distance, duration } or null on failure.
  Future<Map<String, dynamic>?> matchRoute({
    required List<ll.LatLng> points,
    bool snapToTrail = true,
  }) async {
    if (points.length < 2) return null;
    try {
      final sw = Stopwatch()..start();
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('matchRoute');
      Log.i('mapbox.cf', 'Calling matchRoute with ${points.length} points');
      final resp = await callable.call({
        'points': points.map((w) => {'lat': w.latitude, 'lng': w.longitude}).toList(),
        'snapToTrail': snapToTrail,
      });
      final data = Map<String, dynamic>.from(resp.data as Map);
      if (data['geometry'] == null) return null;
      Log.i('mapbox.cf', 'matchRoute OK (${sw.elapsedMilliseconds}ms)');
      return data;
    } catch (e) {
      Log.e('mapbox.cf', 'matchRoute failed', e);
      return null;
    }
  }

  /// Get elevation profile using Terrain-RGB sampling via Cloud Functions.
  /// Input coordinates should be a GeoJSON LineString.coordinates array: [[lng, lat], ...]
  Future<Map<String, dynamic>?> elevationProfile({
    required List<List<double>> coordinates,
    int zoom = 15,
    int sampleEveryMeters = 50,
  }) async {
    if (coordinates.length < 2) return null;
    try {
      final sw = Stopwatch()..start();
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('getElevationProfile');
      Log.i('mapbox.cf', 'Calling getElevationProfile with ${coordinates.length} coords, zoom=$zoom, every=$sampleEveryMeters m');
      final resp = await callable.call({
        'coordinates': coordinates,
        'zoom': zoom,
        'sampleEveryMeters': sampleEveryMeters,
      });
      final data = Map<String, dynamic>.from(resp.data as Map);
      Log.i('mapbox.cf', 'getElevationProfile OK (${sw.elapsedMilliseconds}ms)');
      return data;
    } catch (e) {
      Log.e('mapbox.cf', 'getElevationProfile failed', e);
      return null;
    }
  }
}

class PlaceSuggestion {
  final String id;
  final String text;
  final String placeName;
  final double longitude;
  final double latitude;
  final bool isPoi;

  PlaceSuggestion({required this.id, required this.text, required this.placeName, required this.longitude, required this.latitude, required this.isPoi});

  factory PlaceSuggestion.fromGeoJSON(Map<String, dynamic> json) {
    final center = (json['center'] as List).cast<num>();
    return PlaceSuggestion(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      placeName: json['place_name'] as String? ?? '',
      longitude: center[0].toDouble(),
      latitude: center[1].toDouble(),
      isPoi: ((json['id'] as String? ?? '').startsWith('poi.')),
    );
  }
}

String _removeDiacritics(String input) {
  // Quick-and-light diacritic removal for common Nordic characters and accents
  const mapping = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'å': 'a', 'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Å': 'A',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    'ñ': 'n', 'Ñ': 'N', 'ß': 'ss',
  };
  final sb = StringBuffer();
  for (final ch in input.characters) {
    sb.write(mapping[ch] ?? ch);
  }
  return sb.toString();
}
