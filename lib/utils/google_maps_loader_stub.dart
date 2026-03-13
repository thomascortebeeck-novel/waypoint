/// No-op on non-web. Web implementation injects the Google Maps script.
void ensureGoogleMapsScriptLoaded(String apiKey) {}

/// No-op on non-web. Web implementation waits for the Maps API to be ready.
Future<void> waitForGoogleMapsReady() async {}
