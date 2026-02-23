// Web implementation of Google Maps
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/services/map_marker_service.dart';
import 'package:waypoint/utils/logger.dart';

/// Google Maps widget for web platform
class GoogleMapWidget extends StatefulWidget {
  final ll.LatLng initialCenter;
  final MapConfiguration? configuration;
  final void Function(WaypointMapController)? onMapCreated;
  final List<Widget> overlays;
  
  final Function(ll.LatLng)? onTap;
  final Function(ll.LatLng)? onLongPress;
  final Function(CameraPosition)? onCameraChanged;
  
  final List<MapAnnotation> annotations;
  final List<MapPolyline> polylines;

  const GoogleMapWidget({
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
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetWebState();
}

class _GoogleMapWidgetWebState extends State<GoogleMapWidget> {
  gmaps.GoogleMapController? _mapController;
  final Set<gmaps.Marker> _markers = {};
  final Set<gmaps.Polyline> _polylines = {};
  String? _selectedWaypointId; // Track selected waypoint for visual feedback

  bool _hasInitialized = false;
  bool _isLoadingMarkers = false;
  Timer? _updateDebounce;

  @override
  void initState() {
    super.initState();
    // Pre-warm marker cache for common types to improve initial load
    _preWarmMarkerCache();
    // Don't call _updateMarkers() here - MediaQuery isn't available yet
    // Will be called in didChangeDependencies()
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize markers and polylines after MediaQuery is available
    if (!_hasInitialized) {
      _hasInitialized = true;
      _updateMarkers();
      _updatePolylines();
    }
  }

  @override
  void dispose() {
    _updateDebounce?.cancel();
    super.dispose();
  }

  /// Pre-warm marker cache for common waypoint types
  /// This improves initial load performance by painting markers before they're needed
  void _preWarmMarkerCache() {
    // Pre-warm common types in background (don't await)
    // Use default pixel ratio (2.0) for pre-warming
    final commonTypes = ['accommodation', 'restaurant', 'activity', 'logistics', 'waypoint'];
    
    for (final type in commonTypes) {
      // Fire and forget - cache will be populated asynchronously
      MapMarkerService.markerForType(
        type,
        devicePixelRatio: 2.0, // Default for pre-warming
        isSelected: false,
      ).catchError((e) {
        // Silently fail - cache will be populated when marker is actually needed
      });
    }
  }

  @override
  void didUpdateWidget(GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Debounce marker updates to prevent excessive repaints
    if (oldWidget.annotations != widget.annotations) {
      _updateDebounce?.cancel();
      _updateDebounce = Timer(const Duration(milliseconds: 100), () {
        if (mounted) _updateMarkers();
      });
    }
    if (oldWidget.polylines != widget.polylines) {
      _updatePolylines();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    MapMarkerService.clearCache(); // fires on every hot reload
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;
    
    // Guard against calling setState during a layout/build pass (e.g., during window resize)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoadingMarkers = true;
        });
      }
    });

    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Paint all markers concurrently (not sequentially)
      final futures = widget.annotations.asMap().entries.map((entry) async {
      final i = entry.key;
      final annotation = entry.value;

      // Get type string from waypointType field
      final typeString = annotation.waypointType != null
          ? annotation.waypointType.toString().split('.').last.toLowerCase()
          : 'waypoint'; // fallback

      final isSelected = annotation.id == _selectedWaypointId;

      // Get order number from annotation (set in MapAnnotation.fromWaypoint)
      final orderNumber = annotation.orderNumber;

      // Paint custom marker (async - all paint concurrently)
      final icon = await MapMarkerService.markerForType(
        typeString,
        devicePixelRatio: pixelRatio,
        isSelected: isSelected,
        orderNumber: orderNumber,
      );

      // TODO: Google Maps Marker deprecation warning
      // Console shows: "google.maps.Marker is deprecated. Please use google.maps.marker.AdvancedMarkerElement instead."
      // The google_maps_flutter package (v2.5.0) uses the deprecated Marker API.
      // AdvancedMarkerElement requires:
      //   - A Map ID configured in Google Cloud Console
      //   - Direct JS interop or package update
      // Monitor: https://github.com/flutter/packages for AdvancedMarker support
      // Current workaround: Warning is harmless, markers still function correctly
      return gmaps.Marker(
        markerId: gmaps.MarkerId(annotation.id),
        position: gmaps.LatLng(
          annotation.position.latitude,
          annotation.position.longitude,
        ),
        icon: icon,
        anchor: const Offset(0.5, 1.0), // pin tip touches coordinate
        zIndex: isSelected ? 10.0 : i.toDouble(),
        infoWindow: annotation.showInfoWindow && annotation.label != null
            ? gmaps.InfoWindow(title: annotation.label!)
            : gmaps.InfoWindow.noText,
        draggable: annotation.draggable,
        onTap: () {
          // Guard against calling setState during a layout/build pass
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedWaypointId = annotation.id;
              });
              _updateMarkers(); // Repaint with selection ring
            }
          });
          annotation.onTap?.call();
        },
        onDragEnd: annotation.onDrag != null
            ? (gmaps.LatLng position) => annotation.onDrag!(
                  ll.LatLng(position.latitude, position.longitude),
                )
            : null,
      );
    });

      // Wait for all markers to finish painting concurrently
      final built = await Future.wait(futures);

      if (mounted) {
        // Guard against calling setState during a layout/build pass
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _markers.clear();
              _markers.addAll(built);
              _isLoadingMarkers = false;
            });
          }
        });
      }
    } catch (e) {
      Log.e('google_map', 'Failed to update markers', e);
      if (mounted) {
        // Guard against calling setState during a layout/build pass
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoadingMarkers = false;
            });
          }
        });
      }
    }
  }

  void _updatePolylines() {
    _polylines.clear();
    for (final polyline in widget.polylines) {
      // Determine dash pattern
      List<gmaps.PatternItem> patterns = [];
      if (polyline.isDashed) {
        final dashPattern = polyline.dashPattern ?? [10, 8];
        patterns = [
          gmaps.PatternItem.dash(dashPattern[0].toDouble()),
          gmaps.PatternItem.gap((dashPattern.length > 1 ? dashPattern[1] : 8).toDouble()),
        ];
      } else if (polyline.borderColor != null) {
        // Legacy: borderColor used to indicate dashed
        patterns = [gmaps.PatternItem.dash(10.0), gmaps.PatternItem.gap(5.0)];
      }
      
      _polylines.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId(polyline.id),
          points: polyline.points
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList(),
          color: polyline.colorWithOpacity,
          width: polyline.width.toInt(),
          patterns: patterns,
        ),
      );
    }
    // Guard against calling setState during a layout/build pass
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  double _getMarkerHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  Future<void> _onMapCreated(gmaps.GoogleMapController controller) async {
    _mapController = controller;

    final waypointController = _GoogleMapControllerWeb(
      controller: controller,
      onCameraChanged: widget.onCameraChanged,
    );

    widget.onMapCreated?.call(waypointController);
    Log.i('google_map', '✅ Google Maps created successfully (web)');
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration ?? MapConfiguration.mainMap();
    
    return Stack(
      children: [
        gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: gmaps.LatLng(
              widget.initialCenter.latitude,
              widget.initialCenter.longitude,
            ),
            zoom: config.initialZoom,
            tilt: config.initialTilt,
            bearing: config.initialBearing,
          ),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: _onMapCreated,
          // Show map immediately even while markers are loading
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          onTap: widget.onTap != null
              ? (gmaps.LatLng position) => widget.onTap!(
                    ll.LatLng(position.latitude, position.longitude),
                  )
              : null,
          onLongPress: widget.onLongPress != null
              ? (gmaps.LatLng position) => widget.onLongPress!(
                    ll.LatLng(position.latitude, position.longitude),
                  )
              : null,
          mapType: gmaps.MapType.normal,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: config.initialTilt > 0,
          rotateGesturesEnabled: true,
          compassEnabled: true,
        ),
        // Loading indicator while markers are being painted
        if (_isLoadingMarkers && widget.annotations.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading markers...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ...widget.overlays,
      ],
    );
  }
}

/// Web implementation of WaypointMapController
class _GoogleMapControllerWeb implements WaypointMapController {
  final gmaps.GoogleMapController controller;
  final Function(CameraPosition)? onCameraChanged;
  final _markerDragController = StreamController<MarkerDragEvent>.broadcast();
  final _mapTapController = StreamController<ll.LatLng>.broadcast();
  final _cameraMoveController = StreamController<CameraPosition>.broadcast();
  
  final Map<String, gmaps.Marker> _markers = {};
  final Map<String, gmaps.Polyline> _polylines = {};
  bool _interactionsEnabled = true;

  _GoogleMapControllerWeb({
    required this.controller,
    this.onCameraChanged,
  });

  @override
  Future<void> setCamera(
    ll.LatLng center,
    double zoom, {
    double? bearing,
    double? tilt,
  }) async {
    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(center.latitude, center.longitude),
          zoom: zoom,
          bearing: bearing ?? 0,
          tilt: tilt ?? 0,
        ),
      ),
    );
  }

  @override
  Future<void> animateCamera(
    ll.LatLng center,
    double zoom, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: gmaps.LatLng(center.latitude, center.longitude),
          zoom: zoom,
        ),
      ),
    );
  }

  @override
  Future<void> addRoutePolyline(
    List<ll.LatLng> points, {
    Color color = const Color(0xFF4CAF50),
    double width = 4.0,
  }) async {
    // Implementation would update polylines
  }

  @override
  Future<void> removeRoutePolyline() async {
    // Implementation would remove polylines
  }

  @override
  Future<void> addMarker(
    String id,
    ll.LatLng position, {
    Widget? customWidget,
    String? iconAsset,
    bool draggable = false,
  }) async {
    _markers[id] = gmaps.Marker(
      markerId: gmaps.MarkerId(id),
      position: gmaps.LatLng(position.latitude, position.longitude),
      draggable: draggable,
    );
  }

  @override
  Future<void> removeMarker(String id) async {
    _markers.remove(id);
  }

  @override
  Future<void> setUserLocation(
    ll.LatLng position, {
    double? heading,
  }) async {
    // Google Maps handles user location internally
  }

  @override
  Future<void> setMarkerDraggable(String markerId, bool draggable) async {
    final marker = _markers[markerId];
    if (marker != null) {
      _markers[markerId] = gmaps.Marker(
        markerId: marker.markerId,
        position: marker.position,
        infoWindow: marker.infoWindow,
        icon: marker.icon,
        draggable: draggable,
        onTap: marker.onTap,
        onDragEnd: marker.onDragEnd,
      );
    }
  }

  @override
  Stream<MarkerDragEvent> get onMarkerDrag => _markerDragController.stream;

  @override
  Future<void> updateMarkerPosition(String markerId, ll.LatLng position) async {
    final marker = _markers[markerId];
    if (marker != null) {
      _markers[markerId] = gmaps.Marker(
        markerId: marker.markerId,
        position: gmaps.LatLng(position.latitude, position.longitude),
        infoWindow: marker.infoWindow,
        icon: marker.icon,
        draggable: marker.draggable,
        onTap: marker.onTap,
        onDragEnd: marker.onDragEnd,
      );
    }
  }

  @override
  Stream<ll.LatLng> get onMapTap => _mapTapController.stream;

  @override
  Stream<CameraPosition> get onCameraMove => _cameraMoveController.stream;

  @override
  CameraPosition? get currentPosition {
    return null;
  }

  @override
  Future<void> disableScrollZoom() async {
    // Would need to update map settings
  }

  @override
  Future<void> enableScrollZoom() async {
    // Would need to update map settings
  }

  @override
  Future<void> disableInteractions() async {
    _interactionsEnabled = false;
  }

  @override
  Future<void> enableInteractions() async {
    _interactionsEnabled = true;
  }

  @override
  void dispose() {
    _markerDragController.close();
    _mapTapController.close();
    _cameraMoveController.close();
  }
}

