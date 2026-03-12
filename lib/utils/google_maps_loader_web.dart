import 'dart:html' as html;

/// Injects the Google Maps JavaScript API script on web so the map can display.
/// Uses the given [apiKey] (e.g. Firebase web apiKey from the same Google Cloud project).
void ensureGoogleMapsScriptLoaded(String apiKey) {
  if (apiKey.isEmpty || apiKey.contains('REPLACE')) return;
  if (html.document.querySelector('script[src*="maps.googleapis.com"]') != null) return;
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places,geometry,marker&loading=async'
    ..async = true
    ..defer = true;
  html.document.head!.append(script);
}
