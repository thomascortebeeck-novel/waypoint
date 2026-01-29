/// Mapbox configuration for Waypoint
///
/// ARCHITECTURE:
/// - Mobile (iOS/Android): Mapbox SDK with native vector rendering
/// - Web: Mapbox GL JS with web-optimized custom style
///
/// Platform-specific styles for optimal performance!
///
/// Mapbox web pricing: Free tier includes 50,000 map loads/month
/// https://www.mapbox.com/pricing

import 'package:flutter/foundation.dart' show kIsWeb;

/// Mapbox access token (waypoint token with STYLES:TILES scope)
/// Required scopes: STYLES:TILES, STYLES:READ, FONTS:READ
const mapboxPublicToken = String.fromEnvironment(
  'MAPBOX_PUBLIC_TOKEN',
  defaultValue: 'pk.eyJ1IjoidGhvbWFzY29ydGViZWVjazkzIiwiYSI6ImNtazFtbDhncDA2bDEzZ3F5eXh3Mm9pc3UifQ.Zt295Dc_mTs9L7rvgpJ4dA',
);

// Style IDs - defined once, used everywhere
// Mobile style for native iOS/Android
const _mobileStyleId = 'cmkv0yv7a006401s9akepciwf';
// Web style: user's custom web-optimized style
// Style ID from user: cmkx4kj8 then lowercase-u then 009701 then sb9xmx07qz
final _webStyleId = ['cmkx4kj8', 'u', '009701sb9xmx07qz'].join();

/// Platform-specific style URIs
String get _mobileStyleUri => 'mapbox://styles/thomascortebeeck93/$_mobileStyleId';
String get _webStyleUri => 'mapbox://styles/thomascortebeeck93/$_webStyleId';

/// Custom Waypoint style - Platform-specific
String get mapboxStyleUri => kIsWeb ? _webStyleUri : _mobileStyleUri;

// Alternative style URIs (for future use or testing)
const customWaypointStyle = 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf';
const outdoorsStyle = 'mapbox://styles/thomascortebeeck93/cmkwpnibk001201r4cwe2flf7';
const satelliteStyle = 'mapbox://styles/mapbox/satellite-streets-v12';

// ============================================================================
// RASTER TILE URLS (for flutter_map fallback - map cards, previews, etc.)
// ============================================================================

/// Mobile custom style raster tiles (Static Tiles API)
String get mobileRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/$_mobileStyleId/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Web custom style raster tiles (Static Tiles API)
/// Note: No @2x suffix on web to prevent double scaling on high-DPI displays
String get webRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/$_webStyleId/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken';

/// Outdoors custom style raster tiles (Static Tiles API)
String get outdoorsRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/cmkwpnibk001201r4cwe2flf7/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Satellite style raster tiles - SAFE for Static Tiles API
String get satelliteRasterUrl =>
    'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken';

/// Default raster tile URL for flutter_map - Platform-specific
String get defaultRasterTileUrl => kIsWeb ? webRasterUrl : mobileRasterUrl;

// TileStore path name for offline regions
const mapboxTileStoreName = 'waypoint_tiles';

// Safety check utility
bool get hasValidMapboxToken => mapboxPublicToken.isNotEmpty;
