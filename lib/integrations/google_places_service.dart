import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/utils/logger.dart';

/// 🔒 SECURE Google Places Service using Firebase Cloud Functions
/// All API calls are proxied through backend to protect API keys and implement rate limiting
class GooglePlacesService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Search for places using secure Cloud Function
  /// Returns list of place predictions based on query
  Future<List<PlacePrediction>> searchPlaces({
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

      // Handle rate limiting gracefully
      if (e.code == 'resource-exhausted') {
        throw Exception('Rate limit exceeded. Please try again in a few minutes.');
      }

      // Handle auth errors
      if (e.code == 'unauthenticated') {
        throw Exception('You must be signed in to search places.');
      }

      rethrow;
    } catch (e, stack) {
      Log.e('google_places', '❌ Unexpected error', e, stack);
      return [];
    }
  }

  /// Get detailed information about a specific place using secure Cloud Function
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
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
        throw Exception('Rate limit exceeded. Please try again in a few minutes.');
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
    );
  }
}
