/// Feature flags for map engine selection
/// 
/// These flags control whether to use Mapbox everywhere (like AllTrails) 
/// or maintain the hybrid approach (flutter_map for editing, Mapbox for viewing)
class MapFeatureFlags {
  /// Enable Mapbox everywhere (like AllTrails)
  /// 
  /// When false: Uses hybrid approach (flutter_map for editing, Mapbox for viewing)
  /// When true: Uses Mapbox for all screens including Route Builder
  /// 
  /// To enable: flutter run --dart-define=USE_MAPBOX_EVERYWHERE=true
  static const bool useMapboxEverywhere = bool.fromEnvironment(
    'USE_MAPBOX_EVERYWHERE',
    defaultValue: true, // ✅ Enabled for Dreamflow testing
  );
  
  /// Enable enhanced marker interactions on Mapbox
  /// 
  /// Allows dragging markers in Route Builder when using Mapbox
  /// 
  /// To enable: flutter run --dart-define=ENABLE_MAPBOX_MARKER_DRAG=true
  static const bool enableMapboxMarkerDrag = bool.fromEnvironment(
    'ENABLE_MAPBOX_MARKER_DRAG',
    defaultValue: true,
  );
  
  /// Fallback to flutter_map if Mapbox fails to load
  /// 
  /// Provides graceful degradation if Mapbox has issues
  /// 
  /// To disable: flutter run --dart-define=ALLOW_MAPBOX_FALLBACK=false
  static const bool allowMapboxFallback = bool.fromEnvironment(
    'ALLOW_MAPBOX_FALLBACK',
    defaultValue: true,
  );
  
  /// Use legacy flutter_map editor in Route Builder
  /// 
  /// When true: Uses the proven flutter_map implementation (rollback path)
  /// When false: Uses the new AdaptiveMapWidget with Mapbox (default)
  /// 
  /// This is a SAFETY SWITCH for instant rollback if Mapbox editing has issues.
  /// To enable legacy: flutter run --dart-define=USE_LEGACY_EDITOR=true
  static const bool useLegacyEditor = bool.fromEnvironment(
    'USE_LEGACY_EDITOR',
    defaultValue: false, // Default to new Mapbox editor
  );
}
