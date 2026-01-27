/// Mapbox configuration for Waypoint
///
/// ARCHITECTURE:
/// - Mobile (iOS/Android): Mapbox SDK with native vector rendering
/// - Web: Mapbox GL JS with the SAME custom style
///
/// Both platforms use mapboxStyleUri for visual consistency!
///
/// Mapbox web pricing: Free tier includes 50,000 map loads/month
/// https://www.mapbox.com/pricing

/// Mapbox access token (waypoint token with STYLES:TILES scope)
/// Required scopes: STYLES:TILES, STYLES:READ, FONTS:READ
const mapboxPublicToken = String.fromEnvironment(
  'MAPBOX_PUBLIC_TOKEN',
  defaultValue: 'pk.eyJ1IjoidGhvbWFzY29ydGViZWVjazkzIiwiYSI6ImNtazFtbDhncDA2bDEzZ3F5eXh3Mm9pc3UifQ.Zt295Dc_mTs9L7rvgpJ4dA',
);

/// Custom Waypoint style - USED ON ALL PLATFORMS
/// This is a Mapbox Standard-based style with 3D terrain, custom colors, etc.
/// Works with: Mapbox SDK (mobile), Mapbox GL JS (web)
const mapboxStyleUri = String.fromEnvironment(
  'MAPBOX_STYLE_URI',
  defaultValue: 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf',
);

// Alternative style URIs (for future use or testing)
const customWaypointStyle = 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf';
const outdoorsStyle = 'mapbox://styles/mapbox/outdoors-v12';
const satelliteStyle = 'mapbox://styles/mapbox/satellite-streets-v12';

// Raster tile URL for legacy flutter_map usage (still used in some map cards)
// Using custom Waypoint style for consistent branding
String get customWaypointRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/cmkv0yv7a006401s9akepciwf/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

String get defaultRasterTileUrl => customWaypointRasterUrl;

// TileStore path name for offline regions
const mapboxTileStoreName = 'waypoint_tiles';

// Safety check utility
bool get hasValidMapboxToken => mapboxPublicToken.isNotEmpty;
