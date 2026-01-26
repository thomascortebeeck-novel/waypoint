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
  defaultValue: 'pk.eyJ1IjoidGhvbWFzY29ydGViZWVjazkzIiwiYSI6ImNtZ2YwdHNkcTAyd2gybHNjY3Z4cTNzY2EifQ.JumF23xtbixumEUT62FVKQ',
);

// Custom Waypoint style (for native Mapbox SDK on mobile)
// Note: This vector style does NOT work with flutter_map's raster tile layer
const mapboxStyleUri = String.fromEnvironment(
  'MAPBOX_STYLE_URI',
  defaultValue: 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf',
);

// Alternative style URIs
const customWaypointStyle = 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf';
const outdoorsStyle = 'mapbox://styles/mapbox/outdoors-v12';
const satelliteStyle = 'mapbox://styles/mapbox/satellite-streets-v12';

// ============================================================================
// FLUTTER_MAP RASTER TILE URLS
// ============================================================================
// flutter_map uses raster tiles, not vector tiles. Mapbox's Static Tiles API
// can convert vector styles to raster, but custom styles often fail (422 error).
// 
// Use these URL templates for flutter_map TileLayer:
// - outdoorsRasterUrl: Outdoor/hiking style (recommended for this app)
// - satelliteRasterUrl: Satellite imagery with street labels
// - streetsRasterUrl: Standard street map

/// Outdoor style raster tiles URL for flutter_map (hiking, terrain, trails)
String get outdoorsRasterUrl =>
    'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Satellite style raster tiles URL for flutter_map
String get satelliteRasterUrl =>
    'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Streets style raster tiles URL for flutter_map
String get streetsRasterUrl =>
    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Default raster tile URL for flutter_map (uses outdoors style)
String get defaultRasterTileUrl => outdoorsRasterUrl;

// TileStore path name for offline regions; the native SDK will resolve a
// platform specific directory.
const mapboxTileStoreName = 'waypoint_tiles';

// Safety check utility
bool get hasValidMapboxToken => mapboxPublicToken.isNotEmpty;
