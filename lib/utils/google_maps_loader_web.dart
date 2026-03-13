import 'dart:html' as html;
import 'package:waypoint/utils/logger.dart';

/// Redact API key for safe console logging (first 8 + … + last 4 chars).
String _redactKey(String k) {
  if (k.isEmpty || k.contains('REPLACE') || k == 'YOUR_GOOGLE_MAPS_API_KEY') return '(empty or placeholder)';
  if (k.length <= 12) return '***';
  return '${k.substring(0, 8)}…${k.substring(k.length - 4)}';
}

/// Injects the Google Maps JavaScript API script on web so the map can display.
/// Uses the given [apiKey] (e.g. Firebase web apiKey from the same Google Cloud project).
void ensureGoogleMapsScriptLoaded(String apiKey) {
  if (apiKey.isEmpty || apiKey.contains('REPLACE')) return;
  final existing = html.document.querySelector('script[src*="maps.googleapis.com"]') as html.ScriptElement?;
  if (existing != null) {
    final match = RegExp(r'[?&]key=([^&]+)').firstMatch(existing.src);
    final keyInPage = match != null ? match.group(1) ?? '' : '';
    Log.i('map', 'Google Maps script already in page (from index.html). Key prefix: ${_redactKey(keyInPage)}. If you see ApiTargetBlockedMapError, this key must have "Maps JavaScript API" enabled and allow this origin in Google Cloud Console.');
    return;
  }
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places,geometry,marker&loading=async'
    ..async = true
    ..defer = true;
  html.document.head!.append(script);
  Log.i('map', 'Google Maps script injected by Dart. Key prefix: ${_redactKey(apiKey)}. If you see ApiTargetBlockedMapError, this key must have "Maps JavaScript API" enabled and allow this origin in Google Cloud Console.');
}
