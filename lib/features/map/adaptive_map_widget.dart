import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/vector_map_controller.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/features/map/web/mapbox_web_widget_export.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/utils/logger.dart';

/// Adaptive map widget with hybrid engine architecture
/// 
/// Supports three rendering strategies:
/// 1. flutter_map + raster tiles (stable, for Route Builder)
/// 2. Mapbox native SDK (mobile vector + 3D, for Main Map)
/// 3. Mapbox GL JS (web vector, for Main Map)
///
/// Use MapConfiguration to declaratively choose the engine.
/// Automatically falls back to flutter_map if Mapbox fails to load.
class AdaptiveMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final MapConfiguration? configuration;
  final void Function(WaypointMapController)? onMapCreated;
  final List<Widget> overlays;
  
  // Legacy parameters (deprecated - use configuration instead)
  @Deprecated('Use configuration.initialZoom instead')
  final double? initialZoom;
  @Deprecated('Use configuration.initialTilt instead')
  final double? initialTilt;
  @Deprecated('Use configuration.initialBearing instead')
  final double? initialBearing;

  const AdaptiveMapWidget({
    super.key,
    required this.initialCenter,
    this.configuration,
    this.onMapCreated,
    this.overlays = const [],
    @Deprecated('Use configuration.initialZoom instead') this.initialZoom,
    @Deprecated('Use configuration.initialTilt instead') this.initialTilt,
    @Deprecated('Use configuration.initialBearing instead') this.initialBearing,
  });

  @override
  State<AdaptiveMapWidget> createState() => _AdaptiveMapWidgetState();
}

class _AdaptiveMapWidgetState extends State<AdaptiveMapWidget> {
  VectorMapController? _controller;
  bool _mapboxFailed = false;
  MapConfiguration? _effectiveConfig;

  @override
  void initState() {
    super.initState();
    _effectiveConfig = _resolveConfiguration();
    Log.i('map', '📍 AdaptiveMapWidget initialized with: $_effectiveConfig');
  }

  /// Resolve the effective configuration from widget parameters
  MapConfiguration _resolveConfiguration() {
    // If configuration is provided, use it
    if (widget.configuration != null) {
      return widget.configuration!;
    }

    // Otherwise create a default configuration based on platform
    // and legacy parameters (for backward compatibility)
    final zoom = widget.initialZoom ?? 12.0;
    final tilt = widget.initialTilt ?? 0.0;
    final bearing = widget.initialBearing ?? 0.0;

    if (kIsWeb) {
      return MapConfiguration(
        engineType: MapEngineType.mapboxWebGL,
        styleUri: mapboxStyleUri,
        rasterTileUrl: defaultRasterTileUrl,
        allowFallback: true,
        initialZoom: zoom,
        initialTilt: tilt,
        initialBearing: bearing,
      );
    } else {
      return MapConfiguration(
        engineType: MapEngineType.mapboxNative,
        styleUri: mapboxStyleUri,
        rasterTileUrl: defaultRasterTileUrl,
        allowFallback: true,
        initialZoom: zoom,
        initialTilt: tilt,
        initialBearing: bearing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _effectiveConfig!;

    return Stack(
      children: [
        // Map layer - engine selected based on configuration
        _buildMapLayer(config),
        
        // Overlays (controls, tracking, etc.)
        ...widget.overlays,
        
        // Fallback indicator (debug only)
        if (_mapboxFailed && kDebugMode)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Fallback Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapLayer(MapConfiguration config) {
    // If Mapbox failed and fallback is allowed, use flutter_map
    if (_mapboxFailed && config.allowFallback) {
      Log.w('map', '⚠️ Mapbox failed, falling back to flutter_map raster');
      return _buildFlutterMap(config);
    }

    // Choose engine based on configuration
    switch (config.engineType) {
      case MapEngineType.flutterMapRaster:
        return _buildFlutterMap(config);
      
      case MapEngineType.mapboxNative:
        if (kIsWeb) {
          Log.w('map', '⚠️ Mapbox Native requested on web, using flutter_map');
          return _buildFlutterMap(config);
        }
        return _buildMobileMap(config);
      
      case MapEngineType.mapboxWebGL:
        if (!kIsWeb) {
          Log.w('map', '⚠️ Mapbox WebGL requested on mobile, using Mapbox Native');
          return _buildMobileMap(config);
        }
        return _buildWebMap(config);
    }
  }

  /// Build mobile map using native Mapbox SDK
  /// Full 3D terrain, custom style, offline support via TileStore
  Widget _buildMobileMap(MapConfiguration config) {
    return MapWidget(
      key: const ValueKey('mapbox_native_map'),
      styleUri: config.styleUri ?? mapboxStyleUri,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            widget.initialCenter.longitude,
            widget.initialCenter.latitude,
          ),
        ),
        zoom: config.initialZoom,
        bearing: config.initialBearing,
        pitch: config.initialTilt,
      ),
      onMapCreated: (MapboxMap map) {
        _controller = VectorMapController();
        _controller!.initialize(map);
        widget.onMapCreated?.call(_controller!);
        Log.i('map', '✅ Mapbox Native map created successfully');
      },
      onTapListener: (MapContentGestureContext context) {
        final latLng = LatLng(
          context.point.coordinates.lat.toDouble(),
          context.point.coordinates.lng.toDouble(),
        );
        _controller?.handleTap(latLng);
      },
      onScrollListener: (MapContentGestureContext context) {
        _controller?.handleCameraChange();
      },
    );
  }

  /// Build web map using Mapbox GL JS
  /// Uses the SAME custom style as mobile!
  Widget _buildWebMap(MapConfiguration config) {
    try {
      return MapboxWebWidget(
        key: const ValueKey('mapbox_web_map'),
        initialCenter: widget.initialCenter,
        initialZoom: config.initialZoom,
        initialTilt: config.initialTilt,
        initialBearing: config.initialBearing,
        onMapCreated: (controller) {
          widget.onMapCreated?.call(controller);
          Log.i('map', '✅ Mapbox GL JS map created successfully');
        },
      );
    } catch (e) {
      Log.e('map', '❌ Mapbox GL JS failed to load', e);
      if (config.allowFallback) {
        // Trigger fallback on next rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _mapboxFailed = true;
            });
          }
        });
      }
      return _buildFlutterMap(config);
    }
  }

  /// Build flutter_map with raster tiles
  /// Stable fallback for all platforms
  Widget _buildFlutterMap(MapConfiguration config) {
    final mapController = fm.MapController();
    
    return fm.FlutterMap(
      key: const ValueKey('flutter_map_raster'),
      mapController: mapController,
      options: fm.MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: config.initialZoom,
        interactionOptions: const fm.InteractionOptions(
          flags: fm.InteractiveFlag.all,
          enableMultiFingerGestureRace: true,
        ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: config.rasterTileUrl ?? defaultRasterTileUrl,
          userAgentPackageName: 'com.waypoint.app',
        ),
      ],
    );
  }
}
