import 'package:flutter/foundation.dart';
import 'package:waypoint/features/map/map_feature_flags.dart';

/// Map engine types available in Waypoint
enum MapEngineType {
  /// Flutter Map with raster tiles (Mapbox Static Tiles API)
  /// Use for: Route Builder, Map Preview Cards, Trip Day Maps
  /// Pros: Stable, fast interaction, simple implementation
  /// Cons: No 3D terrain, no vector styling
  flutterMapRaster,
  
  /// Mapbox native SDK (iOS/Android only)
  /// Use for: Main Map, Discovery screens
  /// Pros: Vector tiles, 3D terrain, smooth performance, offline support
  /// Cons: Mobile only, larger app size
  @Deprecated('Use googleMaps instead')
  mapboxNative,
  
  /// Mapbox GL JS (Web only)
  /// Use for: Main Map on web
  /// Pros: Vector tiles, custom styling, interactive
  /// Cons: Web only, requires GL JS loading
  @Deprecated('Use googleMaps instead')
  mapboxWebGL,
  
  /// Google Maps (iOS/Android/Web)
  /// Use for: All map screens
  /// Pros: Native Google Maps experience, consistent across platforms, excellent POI data
  /// Cons: Requires Google Maps API key
  googleMaps,
}

/// Configuration for map rendering
class MapConfiguration {
  /// Which map engine to use
  final MapEngineType engineType;
  
  /// Custom Mapbox style URI (for vector engines)
  final String? styleUri;
  
  /// Custom raster tile URL (for flutter_map)
  final String? rasterTileUrl;
  
  /// Whether to enable 3D terrain (Mapbox native/GL only)
  final bool enable3DTerrain;
  
  /// Whether to allow fallback to flutter_map if Mapbox fails
  final bool allowFallback;
  
  /// Initial zoom level
  final double initialZoom;
  
  /// Initial camera tilt (0 = top-down, 60 = perspective)
  final double initialTilt;
  
  /// Initial camera bearing (rotation in degrees)
  final double initialBearing;
  
  /// Whether markers should be draggable/interactive (for route editing)
  final bool enableInteractiveMarkers;

  const MapConfiguration({
    required this.engineType,
    this.styleUri,
    this.rasterTileUrl,
    this.enable3DTerrain = true,
    this.allowFallback = true,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.enableInteractiveMarkers = false, // Default: view-only markers
  });

  /// Configuration for Route Builder
  /// 
  /// Uses Google Maps for all platforms
  factory MapConfiguration.routeBuilder({
    String? rasterTileUrl,
    String? styleUri,
    double initialZoom = 12.0,
  }) {
    return MapConfiguration(
      engineType: MapEngineType.googleMaps,
      rasterTileUrl: rasterTileUrl,
      allowFallback: true,
      initialZoom: initialZoom,
      enableInteractiveMarkers: true, // Enable marker drag for editing
    );
  }

  /// Configuration for Main Map/Discovery (Google Maps)
  factory MapConfiguration.mainMap({
    String? styleUri,
    String? rasterTileUrl,
    bool enable3DTerrain = true,
    double initialZoom = 12.0,
    double initialTilt = 0.0,
  }) {
    return MapConfiguration(
      engineType: MapEngineType.googleMaps,
      styleUri: styleUri,
      rasterTileUrl: rasterTileUrl,
      enable3DTerrain: enable3DTerrain,
      allowFallback: true,
      initialZoom: initialZoom,
      initialTilt: initialTilt,
    );
  }

  /// Configuration for Preview Cards (lightweight flutter_map)
  factory MapConfiguration.preview({
    String? rasterTileUrl,
    double initialZoom = 13.0,
  }) {
    return MapConfiguration(
      engineType: MapEngineType.flutterMapRaster,
      rasterTileUrl: rasterTileUrl,
      allowFallback: false,
      initialZoom: initialZoom,
    );
  }

  /// Whether this configuration uses Mapbox vector tiles
  @Deprecated('Mapbox is deprecated, use googleMaps instead')
  bool get usesMapboxVector => 
      engineType == MapEngineType.mapboxNative || 
      engineType == MapEngineType.mapboxWebGL;
  
  /// Whether this configuration uses Google Maps
  bool get usesGoogleMaps => engineType == MapEngineType.googleMaps;

  /// Whether this configuration uses flutter_map raster tiles
  bool get usesFlutterMapRaster => 
      engineType == MapEngineType.flutterMapRaster;

  /// Copy with modifications
  MapConfiguration copyWith({
    MapEngineType? engineType,
    String? styleUri,
    String? rasterTileUrl,
    bool? enable3DTerrain,
    bool? allowFallback,
    double? initialZoom,
    double? initialTilt,
    double? initialBearing,
    bool? enableInteractiveMarkers,
  }) {
    return MapConfiguration(
      engineType: engineType ?? this.engineType,
      styleUri: styleUri ?? this.styleUri,
      rasterTileUrl: rasterTileUrl ?? this.rasterTileUrl,
      enable3DTerrain: enable3DTerrain ?? this.enable3DTerrain,
      allowFallback: allowFallback ?? this.allowFallback,
      initialZoom: initialZoom ?? this.initialZoom,
      initialTilt: initialTilt ?? this.initialTilt,
      initialBearing: initialBearing ?? this.initialBearing,
      enableInteractiveMarkers: enableInteractiveMarkers ?? this.enableInteractiveMarkers,
    );
  }

  @override
  String toString() {
    return 'MapConfiguration('
        'engine: $engineType, '
        'styleUri: $styleUri, '
        'rasterUrl: $rasterTileUrl, '
        '3D: $enable3DTerrain, '
        'fallback: $allowFallback'
        ')';
  }
}
