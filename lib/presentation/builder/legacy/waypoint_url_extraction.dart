// LEGACY CODE: URL Extraction for Waypoint Dialog
// This code has been moved to legacy as we now use Google Places API for all waypoint data extraction.
// Kept for reference only - not used in the current implementation.

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/utils/logger.dart';

/// Legacy URL metadata extraction method
/// This was previously used to extract metadata from URLs (e.g., Airbnb, booking.com)
/// Now replaced with Google Places API integration
Future<Map<String, dynamic>?> extractUrlMetadataLegacy(String url) async {
  if (url.trim().isEmpty) {
    return null;
  }

  try {
    Log.i('waypoint_dialog_legacy', 'Calling fetchMeta for URL: $url');
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('fetchMeta');
    final result = await callable.call<Map<String, dynamic>>({'url': url});
    final data = result.data as Map<String, dynamic>?;

    Log.i('waypoint_dialog_legacy', 'fetchMeta response received: $data');

    if (data != null) {
      // Store the metadata including the original URL
      final metadataWithUrl = Map<String, dynamic>.from(data);
      metadataWithUrl['url'] = url; // Store the original URL
      
      return metadataWithUrl;
    }
    
    return null;
  } catch (e) {
    Log.e('waypoint_dialog_legacy', 'Failed to extract metadata', e);
    return null;
  }
}

