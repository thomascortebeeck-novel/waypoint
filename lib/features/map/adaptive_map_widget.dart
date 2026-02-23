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
import 'package:waypoint/features/map/google_map_widget_export.dart';
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
  final WaypointType? waypointType;  // Direct type access for marker generation
  final int? orderNumber;            // For route waypoints with sequence numbers
  final String? label;
  final bool draggable;
  final VoidCallback? onTap;
  final Function(LatLng)? onDrag;
  final double? markerSize; // Optional size override (default: 22 for POIs, 28 for waypoints)
  final double? iconSize; // Optional icon size override (default: 12 for POIs, 16 for waypoints)
  final bool showInfoWindow; // Whether to show Google Maps info window popup
  
  const MapAnnotation({
    required this.id,
    required this.position,
    required this.icon,
    required this.color,
    this.waypointType,
    this.orderNumber,
    this.label,
    this.draggable = false,
    this.onTap,
    this.onDrag,
    this.markerSize,
    this.iconSize,
    this.showInfoWindow = true, // Default to showing info window for backward compatibility
  });
  
  /// Create annotation from RouteWaypoint
  factory MapAnnotation.fromWaypoint(RouteWaypoint waypoint, {
    bool draggable = false,
    bool showInfoWindow = true,
    VoidCallback? onTap,
    Function(LatLng)? onDrag,
  }) {
    return MapAnnotation(
      id: waypoint.id,
      position: waypoint.position,
      icon: getWaypointIcon(waypoint.type),
      color: getWaypointColor(waypoint.type),
      waypointType: waypoint.type,      // Set type directly
      orderNumber: waypoint.order,      // Set order number from RouteWaypoint
      label: waypoint.name,
      draggable: draggable,
      showInfoWindow: showInfoWindow,
      onTap: onTap,
      onDrag: onDrag,
      markerSize: 28, // Custom waypoints are larger
      iconSize: 16, // Larger icons for better visibility
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
      waypointType: null,  // POIs don't have WaypointType
      orderNumber: null,   // POIs don't have order numbers
      label: poi.name,
      draggable: false,
      onTap: onTap,
      markerSize: 22, // OSM POIs match Mapbox native size
      iconSize: 12, // Standard icon size for POIs
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
  final bool isDashed; // Whether to render as dashed line
  final List<int>? dashPattern; // Dash pattern: [dashLength, gapLength] in pixels
  final double opacity; // Opacity (0.0 to 1.0)
  
  const MapPolyline({
    required this.id,
    required this.points,
    this.color = const Color(0xFF4CAF50),
    this.width = 5.0,
    this.borderColor,
    this.borderWidth,
    this.isDashed = false,
    this.dashPattern,
    this.opacity = 1.0,
  });
  
  /// Get color with opacity applied
  Color get colorWithOpacity => color.withOpacity(opacity);
}

/// Adaptive map widget with hybrid engine architecture
/// 
/// Supports rendering strategies:
/// 1. Google Maps (primary - iOS, Android, Web) - used for all map screens
/// 2. flutter_map + raster tiles (fallback for Route Builder if needed)
///
/// Use MapConfiguration to declaratively choose the engine.
/// Automatically falls back to flutter_map if Google Maps fails to load.
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

    // Otherwise create a default configuration using Google Maps
    // and legacy parameters (for backward compatibility)
    final zoom = widget.initialZoom ?? 12.0;
    final tilt = widget.initialTilt ?? 0.0;
    final bearing = widget.initialBearing ?? 0.0;

    // Use Google Maps for all platforms (iOS, Android, Web)
    return MapConfiguration(
      engineType: MapEngineType.googleMaps,
      allowFallback: true,
      initialZoom: zoom,
      initialTilt: tilt,
      initialBearing: bearing,
    );
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
    // If Google Maps failed and fallback is allowed, use flutter_map
    if (_mapboxFailed && config.allowFallback) {
      Log.w('map', '⚠️ Google Maps failed, falling back to flutter_map raster');
      return _buildFlutterMap(config);
    }

    // Choose engine based on configuration
    switch (config.engineType) {
      case MapEngineType.flutterMapRaster:
        return _buildFlutterMap(config);
      
      case MapEngineType.googleMaps:
        return _buildGoogleMap(config);
      
      case MapEngineType.mapboxNative:
        // Deprecated: Mapbox Native is no longer used, fallback to Google Maps
        Log.w('map', '⚠️ Mapbox Native is deprecated, using Google Maps instead');
        return _buildGoogleMap(config);
      
      case MapEngineType.mapboxWebGL:
        // Deprecated: Mapbox WebGL is no longer used, fallback to Google Maps
        Log.w('map', '⚠️ Mapbox WebGL is deprecated, using Google Maps instead');
        return _buildGoogleMap(config);
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

  /// Build Google Maps (works on both mobile and web)
  Widget _buildGoogleMap(MapConfiguration config) {
    try {
      return GoogleMapWidget(
        key: const ValueKey('google_map'),
        initialCenter: widget.initialCenter,
        configuration: config,
        annotations: widget.annotations,
        polylines: widget.polylines,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onCameraChanged: widget.onCameraChanged,
        overlays: widget.overlays,
        onMapCreated: (controller) {
          widget.onMapCreated?.call(controller);
          Log.i('map', '✅ Google Maps created successfully');
        },
      );
    } catch (e) {
      Log.e('map', '❌ Google Maps failed to load', e);
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
                color: poly.colorWithOpacity,
                strokeWidth: poly.width,
                borderColor: poly.borderColor ?? Colors.transparent,
                borderStrokeWidth: poly.borderWidth ?? 0,
                // Note: flutter_map doesn't support dash patterns directly
                // Visual distinction is achieved through opacity and color differences
              );
            }).toList(),
          ),
        // Markers layer
        if (widget.annotations.isNotEmpty)
          fm.MarkerLayer(
            markers: widget.annotations.map((annotation) {
              // Check if this is a start/end marker (single character label like "A" or "B")
              final isStartEndMarker = annotation.label != null && 
                  annotation.label!.length == 1 && 
                  (annotation.label == 'A' || annotation.label == 'B');
              
              // Determine marker size: start/end = 40, waypoint = 28, POI = 22
              final markerSize = isStartEndMarker 
                  ? 40.0 
                  : (annotation.markerSize ?? 22.0);
              final iconSize = isStartEndMarker 
                  ? 18.0 
                  : (annotation.iconSize ?? 12.0);
              final borderWidth = isStartEndMarker 
                  ? 3.0 
                  : (markerSize == 28.0 ? 2.5 : 2.0); // Thicker border for waypoints
              
              return fm.Marker(
                point: annotation.position,
                width: markerSize,
                height: markerSize,
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
                  child: isStartEndMarker
                      ? Container(
                          width: markerSize,
                          height: markerSize,
                          decoration: BoxDecoration(
                            color: annotation.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: borderWidth),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              annotation.label!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: markerSize,
                          height: markerSize,
                          decoration: BoxDecoration(
                            color: annotation.color, // FILL with category color
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: borderWidth), // WHITE border
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Material( // FIX: Prevents "box" icons on Web
                              type: MaterialType.transparency,
                              child: Icon(
                                annotation.icon,
                                color: Colors.white, // WHITE icon for visibility
                                size: iconSize,
                              ),
                            ),
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
