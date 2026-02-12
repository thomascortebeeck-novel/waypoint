import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/utils/logger.dart';

/// 🔒 SECURE Google Places Service using Firebase Cloud Functions
/// All API calls are proxied through backend to protect API keys and implement rate limiting
class GooglePlacesService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // 📦 Cache for search results (reduces redundant API calls)
  final Map<String, List<PlacePrediction>> _searchCache = {};
  final Map<String, PlaceDetails> _detailsCache = {};
  
  // 🔄 Prevent duplicate simultaneous requests
  final Map<String, Future<List<PlacePrediction>>> _inflightSearches = {};
  final Map<String, Future<PlaceDetails?>> _inflightDetails = {};

  /// Search for places using secure Cloud Function with caching and deduplication
  /// Returns list of place predictions based on query
  Future<List<PlacePrediction>> searchPlaces({
    required String query,
    ll.LatLng? proximity,
    List<String>? types,
  }) async {
    // Normalize query
    final normalizedQuery = query.trim().toLowerCase();
    
    // Check cache first
    final cacheKey = _getCacheKey(normalizedQuery, proximity, types);
    if (_searchCache.containsKey(cacheKey)) {
      Log.i('google_places', '📦 Cache hit for: "$query"');
      return _searchCache[cacheKey]!;
    }

    // Deduplicate simultaneous requests
    if (_inflightSearches.containsKey(cacheKey)) {
      Log.i('google_places', '🔄 Waiting for in-flight request: "$query"');
      return _inflightSearches[cacheKey]!;
    }

    // Create the search future
    final searchFuture = _performSearch(
      query: query,
      proximity: proximity,
      types: types,
    );
    
    _inflightSearches[cacheKey] = searchFuture;

    try {
      final results = await searchFuture;
      
      // Cache results (5-minute TTL handled by simple cache)
      _searchCache[cacheKey] = results;
      
      // Cache cleanup (keep last 50 searches)
      if (_searchCache.length > 50) {
        _searchCache.remove(_searchCache.keys.first);
      }
      
      return results;
    } finally {
      _inflightSearches.remove(cacheKey);
    }
  }

  String _getCacheKey(String query, ll.LatLng? proximity, List<String>? types) {
    return '$query|${proximity?.latitude}|${proximity?.longitude}|${types?.join(',')}';
  }

  Future<List<PlacePrediction>> _performSearch({
    required String query,
    ll.LatLng? proximity,
    List<String>? types,
  }) async {
    try {
      Log.i('google_places', '🔍 Searching: "$query"');

      final result = await _functions.httpsCallable('placesSearch').call({
        'query': query,
        if (proximity != null)
          'proximity': {
            'lat': proximity.latitude,
            'lng': proximity.longitude,
          },
        if (types != null) 'types': types,
      });

      final predictions = (result.data['predictions'] as List)
          .map((json) => PlacePrediction.fromJson(json as Map<String, dynamic>))
          .toList();

      Log.i('google_places', '✅ Found ${predictions.length} results');
      return predictions;
    } on FirebaseFunctionsException catch (e) {
      Log.e('google_places', '❌ Search failed: ${e.code} - ${e.message}', e);

      if (e.code == 'resource-exhausted') {
        throw Exception('Too many searches. Please wait a moment and try again.');
      }

      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to search places.');
      }

      rethrow;
    } catch (e, stack) {
      Log.e('google_places', '❌ Unexpected error', e, stack);
      return [];
    }
  }

  /// Get detailed information about a specific place with caching
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // Check cache first
    if (_detailsCache.containsKey(placeId)) {
      Log.i('google_places', '📦 Cache hit for details: $placeId');
      return _detailsCache[placeId];
    }

    // Deduplicate simultaneous requests
    if (_inflightDetails.containsKey(placeId)) {
      Log.i('google_places', '🔄 Waiting for in-flight details request: $placeId');
      return _inflightDetails[placeId];
    }

    final detailsFuture = _performDetailsRequest(placeId);
    _inflightDetails[placeId] = detailsFuture;

    try {
      final details = await detailsFuture;
      if (details != null) {
        _detailsCache[placeId] = details;
        
        // Cache cleanup (keep last 100 places)
        if (_detailsCache.length > 100) {
          _detailsCache.remove(_detailsCache.keys.first);
        }
      }
      return details;
    } finally {
      _inflightDetails.remove(placeId);
    }
  }

  Future<PlaceDetails?> _performDetailsRequest(String placeId) async {
    try {
      Log.i('google_places', '📍 Fetching details for: $placeId');

      final result = await _functions.httpsCallable('placeDetails').call({
        'placeId': placeId,
      });

      final details = PlaceDetails.fromJson(result.data as Map<String, dynamic>);
      Log.i('google_places', '✅ Details retrieved: ${details.name}');
      return details;
    } on FirebaseFunctionsException catch (e) {
      Log.e('google_places', '❌ Details fetch failed: ${e.code} - ${e.message}', e);

      if (e.code == 'resource-exhausted') {
        throw Exception('Too many requests. Please wait a moment and try again.');
      }

      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to fetch place details.');
      }

      return null;
    } catch (e, stack) {
      Log.e('google_places', '❌ Unexpected error', e, stack);
      return null;
    }
  }

  /// Geocode address using secure Cloud Function
  /// Used for Airbnb properties that only have addresses
  Future<ll.LatLng?> geocodeAddress(String address) async {
    try {
      Log.i('google_places', '📍 Geocoding: "$address"');

      final result = await _functions.httpsCallable('geocodeAddress').call({
        'address': address,
      });

      final lat = result.data['latitude'] as double?;
      final lng = result.data['longitude'] as double?;

      if (lat == null || lng == null) {
        Log.w('google_places', '⚠️ No location found for address');
        return null;
      }

      Log.i('google_places', '✅ Location found: $lat, $lng');
      return ll.LatLng(lat, lng);
    } on FirebaseFunctionsException catch (e) {
      Log.e('google_places', '❌ Geocode failed: ${e.code} - ${e.message}', e);

      if (e.code == 'resource-exhausted') {
        throw Exception('Rate limit exceeded. Please try again in a few minutes.');
      }

      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to geocode addresses.');
      }

      return null;
    } catch (e, stack) {
      Log.e('google_places', '❌ Unexpected error', e, stack);
      return null;
    }
  }

  /// Get cached photo URL using secure Cloud Function
  /// Photos are fetched from Google once and cached in Firebase Storage permanently
  /// This significantly reduces API costs as photos are shared across all users
  Future<String?> getCachedPhotoUrl(String photoReference, String waypointId) async {
    try {
      Log.i('google_places', '📸 Fetching photo: $photoReference');

      final result = await _functions.httpsCallable('placePhoto').call({
        'photoReference': photoReference,
        'maxWidth': 800,
        'waypointId': waypointId,
      });

      final url = result.data['url'] as String?;
      Log.i('google_places', '✅ Photo URL: $url');
      return url;
    } on FirebaseFunctionsException catch (e) {
      Log.e('google_places', '❌ Photo fetch failed: ${e.code} - ${e.message}', e);

      if (e.code == 'resource-exhausted') {
        throw Exception('Rate limit exceeded. Please try again in a few minutes.');
      }

      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to fetch photos.');
      }

      return null;
    } catch (e, stack) {
      Log.e('google_places', '❌ Unexpected error', e, stack);
      return null;
    }
  }

  /// Get photo URL for a place photo (deprecated - use getCachedPhotoUrl)
  @Deprecated('Use getCachedPhotoUrl for secure, cached photo access')
  String getPhotoUrl(String photoName, {int maxWidth = 400}) {
    throw UnsupportedError('Direct photo URLs are no longer supported. Use getCachedPhotoUrl() instead.');
  }
}

/// Place prediction from autocomplete search
class PlacePrediction {
  final String placeId;
  final String text;

  PlacePrediction({
    required this.placeId,
    required this.text,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) => PlacePrediction(
        placeId: json['placeId'] as String,
        text: json['text'] as String,
      );
}

/// Review information from Google Places
class PlaceReview {
  final String? authorName;
  final double? rating;
  final String? text;
  final String? publishTime;

  PlaceReview({
    this.authorName,
    this.rating,
    this.text,
    this.publishTime,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      authorName: json['authorName'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      text: json['text'] as String?,
      publishTime: json['publishTime'] as String?,
    );
  }
}

/// Detailed place information
class PlaceDetails {
  final String placeId;
  final String name;
  final String? address;
  final ll.LatLng location;
  final double? rating;
  final String? website;
  final String? phoneNumber;
  final List<String> types;
  final String? photoReference;
  final String? description;
  final int? userRatingCount;
  final List<PlaceReview> reviews;
  final int? priceLevel; // 0=free, 1=$, 2=$$, 3=$$$, 4=$$$$

  PlaceDetails({
    required this.placeId,
    required this.name,
    this.address,
    required this.location,
    this.rating,
    this.website,
    this.phoneNumber,
    this.types = const [],
    this.photoReference,
    this.description,
    this.userRatingCount,
    this.reviews = const [],
    this.priceLevel,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      location: ll.LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      website: json['website'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
      photoReference: json['photoReference'] as String?,
      description: json['description'] as String?,
      userRatingCount: json['userRatingCount'] != null ? (json['userRatingCount'] as num).toInt() : null,
      reviews: (json['reviews'] as List<dynamic>?)?.map((r) => PlaceReview.fromJson(r as Map<String, dynamic>)).toList() ?? [],
      priceLevel: json['priceLevel'] != null ? (json['priceLevel'] as num).toInt() : null,
    );
  }

  /// Convert priceLevel to dollar signs string
  String? get priceRangeString {
    if (priceLevel == null) return null;
    switch (priceLevel) {
      case 0:
        return 'Free';
      case 1:
        return '\$';
      case 2:
        return '\$\$';
      case 3:
        return '\$\$\$';
      case 4:
        return '\$\$\$\$';
      default:
        return null;
    }
  }
}
