/// Mapbox configuration for Waypoint
///
/// Tokens are normally provided via --dart-define at build time. Since you
/// provided a public token, we set it as the default so geocoding works in
/// Dreamflow immediately. You can still override it with --dart-define.
/// Example when running or building for mobile:
/// flutter run --dart-define=MAPBOX_PUBLIC_TOKEN=pk.XXXX
///
/// Note: In Dreamflow web preview, native Mapbox is not available. We keep
/// a graceful FlutterMap fallback for web while still using Mapbox APIs.

const mapboxPublicToken = String.fromEnvironment(
  'MAPBOX_PUBLIC_TOKEN',
  defaultValue: 'pk.eyJ1IjoidGhvbWFzY29ydGViZWVjazkzIiwiYSI6ImNtazFtbDhncDA2bDEzZ3F5eXh3Mm9pc3UifQ.Zt295Dc_mTs9L7rvgpJ4dA',
);

// Default Outdoors style; teams can override with --dart-define.
const mapboxStyleUri = String.fromEnvironment(
  'MAPBOX_STYLE_URI',
  defaultValue: 'mapbox://styles/mapbox/outdoors-v12',
);

// TileStore path name for offline regions; the native SDK will resolve a
// platform specific directory.
const mapboxTileStoreName = 'waypoint_tiles';

// Safety check utility
bool get hasValidMapboxToken => mapboxPublicToken.isNotEmpty;
