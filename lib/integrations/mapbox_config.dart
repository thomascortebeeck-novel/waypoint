/// Mapbox configuration for Waypoint
///
/// ARCHITECTURE:
/// - Mobile (iOS/Android): Mapbox SDK with native vector rendering
/// - Web: Mapbox GL JS with web-optimized custom style
///
/// Platform-specific styles for optimal performance!

import 'package:flutter/foundation.dart' show kIsWeb;

/// Mapbox access token (waypoint token with STYLES:TILES scope)
const mapboxPublicToken = String.fromEnvironment(
  'MAPBOX_PUBLIC_TOKEN',
  defaultValue: 'pk.eyJ1IjoidGhvbWFzY29ydGViZWVjazkzIiwiYSI6ImNtazFtbDhncDA2bDEzZ3F5eXh3Mm9pc3UifQ.Zt295Dc_mTs9L7rvgpJ4dA',
);

// ✅ UPDATED: Using your new Outdoors template style (created from Mapbox Gallery)
// This style is based on Mapbox Standard and has no JSON syntax errors
const _waypointStyleId = 'cmkzt3kvv003701r11e0w1rkl';

/// Platform-specific style URIs - Custom Waypoint Outdoors style
String get _styleUri => 'mapbox://styles/thomascortebeeck93/$_waypointStyleId';

/// Custom Waypoint style - Same on all platforms for visual consistency
String get mapboxStyleUri => _styleUri;

// Alternative style URIs (for testing/rollback)
const oldCustomStyle = 'mapbox://styles/thomascortebeeck93/cmkv0yv7a006401s9akepciwf'; // Had JSON errors
const outdoorsStyle = 'mapbox://styles/thomascortebeeck93/cmkwpnibk001201r4cwe2flf7';
const satelliteStyle = 'mapbox://styles/mapbox/satellite-streets-v12';

// Raster tile URLs
String get mobileRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/$_waypointStyleId/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken' ;

String get webRasterUrl =>
    'https://api.mapbox.com/styles/v1/thomascortebeeck93/$_waypointStyleId/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken' ;

String get defaultRasterTileUrl => kIsWeb ? webRasterUrl : mobileRasterUrl;

const mapboxTileStoreName = 'waypoint_tiles';

bool get hasValidMapboxToken => mapboxPublicToken.isNotEmpty;
