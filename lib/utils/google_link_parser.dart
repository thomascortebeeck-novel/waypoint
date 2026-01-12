import 'package:http/http.dart' as http;
import 'package:waypoint/utils/logger.dart';

/// Utility for parsing Google Maps links and extracting place IDs
class GoogleLinkParser {
  /// Check if text is a valid Google Maps URL
  static bool isGoogleMapsUrl(String text) {
    final normalized = text.toLowerCase().trim();
    
    // Must start with http or https
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      return false;
    }
    
    // Check for Google Maps domains
    return normalized.contains('google.com/maps') ||
        normalized.contains('goo.gl/maps') ||
        normalized.contains('maps.app.goo.gl') ||
        normalized.contains('maps.google.com') ||
        normalized.contains('share.google');
  }

  /// Extract place ID from various Google Maps URL formats
  static String? extractPlaceId(String url) {
    // Format 1: place_id parameter (most reliable)
    // Example: https://maps.google.com/?q=place_id:ChIJ...
    final placeIdMatch = RegExp(r'place_id[=:]([A-Za-z0-9_-]+)').firstMatch(url);
    if (placeIdMatch != null) {
      return placeIdMatch.group(1);
    }

    // Format 2: /place/ URL with data parameter
    // Example: https://www.google.com/maps/place/.../@.../data=...!1sChIJ...
    final placeMatch = RegExp(r'/place/[^/]+.*!1s([A-Za-z0-9_-]+)').firstMatch(url);
    if (placeMatch != null) {
      return placeMatch.group(1);
    }

    // Format 3: ftid parameter (less common)
    final ftidMatch = RegExp(r'ftid=([A-Za-z0-9_-]+)').firstMatch(url);
    if (ftidMatch != null) {
      return ftidMatch.group(1);
    }

    return null;
  }

  /// Expand short URL to get full URL with place ID
  static Future<String?> expandShortUrl(String shortUrl) async {
    try {
      Log.i('google_link_parser', 'Expanding short URL: $shortUrl');

      // Follow redirects to get the full URL
      final response = await http.head(
        Uri.parse(shortUrl),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.request?.url != null) {
        final fullUrl = response.request!.url.toString();
        Log.i('google_link_parser', 'Expanded to: $fullUrl');
        return extractPlaceId(fullUrl);
      }
    } catch (e) {
      Log.e('google_link_parser', 'Failed to expand short URL', e);
    }
    return null;
  }
}
