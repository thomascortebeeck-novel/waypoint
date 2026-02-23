import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Result of fetching metadata from a URL (e.g. Open Graph / link preview).
/// Used by WaypointEditPage when the user pastes a URL.
class UrlMetadataResult {
  final String? name;
  final String? address;
  final String? description;
  final String? imageUrl;
  final ll.LatLng? latLng;
  final String? website;

  const UrlMetadataResult({
    this.name,
    this.address,
    this.description,
    this.imageUrl,
    this.latLng,
    this.website,
  });
}

/// Service for fetching metadata from URLs (e.g. hotel/restaurant links).
/// Calls the [fetchMeta] Cloud Function to extract Open Graph / page metadata.
class UrlMetadataService {
  /// Fetches metadata from the given URL via the fetchMeta Cloud Function.
  /// On success, returns [UrlMetadataResult] and the edit page can go to Step 2 with prefilled fields.
  /// Returns null on failure or when the function returns no usable data.
  Future<UrlMetadataResult?> fetchFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))) {
      return null;
    }
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('fetchMeta');
      final result = await callable.call<Map<String, dynamic>>({'url': trimmed});
      final data = result.data;
      if (data == null) return null;

      final title = data['title'] as String?;
      final description = data['description'] as String?;
      final image = data['image'] as String?;
      final lat = data['latitude'];
      final lng = data['longitude'];
      final addressObj = data['address'];

      // Function returns best result when title || image; treat empty title as no data
      final name = (title != null && title.trim().isNotEmpty) ? title.trim() : null;
      if (name == null && image == null) return null;

      String? address;
      if (addressObj is Map<String, dynamic> && addressObj['formatted'] != null) {
        address = addressObj['formatted'] as String?;
      }
      if (address == null && addressObj is Map<String, dynamic>) {
        final parts = <String>[];
        if (addressObj['street'] != null) parts.add(addressObj['street'] as String);
        if (addressObj['locality'] != null) parts.add(addressObj['locality'] as String);
        if (addressObj['region'] != null) parts.add(addressObj['region'] as String);
        if (addressObj['postalCode'] != null) parts.add(addressObj['postalCode'] as String);
        if (addressObj['country'] != null) parts.add(addressObj['country'] as String);
        if (parts.isNotEmpty) address = parts.join(', ');
      }

      ll.LatLng? latLng;
      if (lat != null && lng != null) {
        final latVal = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
        final lngVal = lng is num ? lng.toDouble() : double.tryParse(lng.toString());
        if (latVal != null && lngVal != null) {
          latLng = ll.LatLng(latVal, lngVal);
        }
      }

      return UrlMetadataResult(
        name: name,
        address: address?.trim().isEmpty == true ? null : address,
        description: (description != null && description.trim().isNotEmpty) ? description.trim() : null,
        imageUrl: image as String?,
        latLng: latLng,
        website: trimmed,
      );
    } on FirebaseFunctionsException catch (e) {
      // Log and return null so UI shows "Could not load link. Add details manually."
      return null;
    } catch (_) {
      return null;
    }
  }
}
