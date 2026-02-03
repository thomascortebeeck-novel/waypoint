import 'dart:async';
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
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/poi_model.dart';

/// Map annotation for rendering waypoints, POIs, and route points
class MapAnnotation {
  final String id;
  final LatLng position;
  final IconData icon;
  final Color color;
  final String? label;
  final bool draggable;
  final VoidCallback? onTap;
  final Function(LatLng)? onDrag;
  
  const MapAnnotation({
    required this.id,
    required this.position,
    required this.icon,
    required this.color,
    this.label,
    this.draggable = false,
    this.onTap,
    this.onDrag,
  });
  
  /// Create annotation from RouteWaypoint
  factory MapAnnotation.fromWaypoint(RouteWaypoint waypoint, {
    bool draggable = false,
    VoidCallback? onTap,
    Function(LatLng)? onDrag,
  }) {
    return MapAnnotation(
      id: waypoint.id,
      position: waypoint.position,
      icon: getWaypointIcon(waypoint.type),
      color: getWaypointColor(waypoint.type),
      label: waypoint.name,
      draggable: draggable,
      onTap: onTap,
      onDrag: onDrag,
    );
  }
  
  /// Create annotation from POI
  factory MapAnnotation.fromPOI(POI poi, {
    VoidCallback? onTap,
  }) {
    return MapAnnotation(
      id: poi.id,
      position: poi.coordinates,
      icon: poi.type.icon,
      color: poi.type.color,
      label: poi.name,
      draggable: false,
      onTap: onTap,
    );
  }
}

/// Map polyline for rendering routes
class MapPolyline {
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  final Color? borderColor;
  final double? borderWidth;
  
  const MapPolyline({
    required this.id,
    required this.points,
    this.color = const Color(0xFF4CAF50),
    this.width = 5.0,
    this.borderColor,
    this.borderWidth,
  });
}

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
  
  // Interaction callbacks for editing
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final Function(CameraPosition)? onCameraChanged;
  
  // Annotations and polylines for rendering
  final List<MapAnnotation> annotations;
  final List<MapPolyline> polylines;
  
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
    this.onTap,
    this.onLongPress,
    this.onCameraChanged,
    this.annotations = const [],
    this.polylines = const [],
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
  
  /// Stream subscription for camera move events (Issue #1 fix - memory leak)
  StreamSubscription<CameraPosition>? _cameraMoveSubscription;

  @override
  void initState() {
    super.initState();
    _effectiveConfig = _resolveConfiguration();
    Log.i('map', '📍 AdaptiveMapWidget initialized with: $_effectiveConfig');
  }
  
  @override
  void dispose() {
    // Cancel camera stream subscription to prevent memory leak
    _cameraMoveSubscription?.cancel();
    _cameraMoveSubscription = null;
    Log.i('map', '🧹 AdaptiveMapWidget disposed, camera subscription cancelled');
    super.dispose();
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
      onMapCreated: (MapboxMap map) async {
        _controller = VectorMapController();
        _controller!.initialize(map);
        widget.onMapCreated?.call(_controller!);
        Log.i('map', '✅ Mapbox Native map created successfully');
        
        // Subscribe to camera move stream to forward to widget callback (Issue #1 fix)
        // Cancel any existing subscription before creating new one
        _cameraMoveSubscription?.cancel();
        _cameraMoveSubscription = _controller!.onCameraMove.listen((cameraPos) {
          widget.onCameraChanged?.call(cameraPos);
        });
      },
      onTapListener: (MapContentGestureContext context) {
        final latLng = LatLng(
          context.point.coordinates.lat.toDouble(),
          context.point.coordinates.lng.toDouble(),
        );
        _controller?.handleTap(latLng);
        widget.onTap?.call(latLng);
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
        annotations: widget.annotations,
        polylines: widget.polylines,
        onTap: widget.onTap, // Forward map tap callback
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
        onTap: widget.onTap != null
            ? (_, latLng) => widget.onTap!(latLng)
            : null,
        onLongPress: widget.onLongPress != null
            ? (_, latLng) => widget.onLongPress!(latLng)
            : null,
        onPositionChanged: widget.onCameraChanged != null
            ? (position, hasGesture) {
                widget.onCameraChanged!(CameraPosition(
                  center: position.center ?? widget.initialCenter,
                  zoom: position.zoom ?? config.initialZoom,
                  bearing: 0,
                  tilt: 0,
                ));
              }
            : null,
      ),
      children: [
        fm.TileLayer(
          urlTemplate: config.rasterTileUrl ?? defaultRasterTileUrl,
          userAgentPackageName: 'com.waypoint.app',
        ),
        // Polylines layer
        if (widget.polylines.isNotEmpty)
          fm.PolylineLayer(
            polylines: widget.polylines.map((poly) {
              return fm.Polyline(
                points: poly.points,
                color: poly.color,
                strokeWidth: poly.width,
                borderColor: poly.borderColor ?? Colors.transparent,
                borderStrokeWidth: poly.borderWidth ?? 0,
              );
            }).toList(),
          ),
        // Markers layer
        if (widget.annotations.isNotEmpty)
          fm.MarkerLayer(
            markers: widget.annotations.map((annotation) {
              return fm.Marker(
                point: annotation.position,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: annotation.onTap,
                  onPanUpdate: annotation.draggable && annotation.onDrag != null
                      ? (details) {
                          // Convert screen position to LatLng
                          // Note: This is a simplified version, proper implementation
                          // would require screen-to-map coordinate conversion
                          annotation.onDrag!(annotation.position);
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: annotation.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      annotation.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
