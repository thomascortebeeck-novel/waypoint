import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
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
    var keyInPage = '';
    if (match != null) {
      try {
        keyInPage = Uri.decodeComponent(match.group(1) ?? '');
      } catch (_) {
        keyInPage = match.group(1) ?? '';
      }
    }
    final validKey = keyInPage.length >= 20 && keyInPage.length <= 100 && !keyInPage.contains('<') && (keyInPage.startsWith('AIza') || RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(keyInPage));
    if (!validKey) {
      Log.i('map', 'Removing invalid Maps script (bad key from index.html, e.g. 404 returned HTML). Injecting with Dart key.');
      existing.remove();
    } else {
      Log.i('map', 'Google Maps script already in page (from index.html). Key prefix: ${_redactKey(keyInPage)}.');
      return;
    }
  }
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places,geometry,marker&loading=async'
    ..async = true
    ..defer = true;
  html.document.head!.append(script);
  Log.i('map', 'Google Maps script injected by Dart. Key prefix: ${_redactKey(apiKey)}. If you see ApiTargetBlockedMapError, this key must have "Maps JavaScript API" enabled and allow this origin in Google Cloud Console.');
}

/// Returns a Future that completes when the Google Maps JavaScript API is ready (window.google.maps defined).
/// Use this before building the map widget when the script is loaded asynchronously (e.g. from index.html).
Future<void> waitForGoogleMapsReady() async {
  const maxWait = Duration(seconds: 15);
  const step = Duration(milliseconds: 100);
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final g = js.context['google'];
      if (g != null && g['maps'] != null) return;
    } catch (_) {}
    await Future.delayed(step);
  }
  Log.e('map', 'Google Maps API did not load within ${maxWait.inSeconds}s');
  throw TimeoutException('Google Maps API did not load within ${maxWait.inSeconds}s');
}
