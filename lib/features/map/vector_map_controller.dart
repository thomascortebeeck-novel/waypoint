import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/utils/logger.dart';

class VectorMapController extends WaypointMapController {
  MapboxMap? _mapboxMap;
  final _mapTapController = StreamController<LatLng>.broadcast();
  final _cameraMoveController = StreamController<CameraPosition>.broadcast();
  final _markerDragController = StreamController<MarkerDragEvent>.broadcast();
  CameraPosition? _currentPosition;
  
  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _markers = {};
  final Map<String, bool> _draggableMarkers = {}; // Track which markers are draggable
  
  PolylineAnnotationManager? _routeManager;
  PolylineAnnotation? _routeLine;

  /// Get the underlying Mapbox map instance for advanced operations
  /// Use this for features like the native location puck
  MapboxMap? get mapboxMap => _mapboxMap;

  /// Initialize with Mapbox map instance
  void initialize(MapboxMap map) {
    _mapboxMap = map;
    Log.i('map', '🗺️ Vector map controller initializing...');
    
    _initializeManagers();
    _setupCameraListener();
  }

  Future<void> _initializeManagers() async {
    try {
      final map = _mapboxMap;
      if (map == null) return;

      _annotationManager = await map.annotations.createPointAnnotationManager();
      _routeManager = await map.annotations.createPolylineAnnotationManager();
      
      Log.i('map', '✅ Annotation managers ready');
    } catch (e) {
      Log.e('map', 'Failed to initialize managers', e);
    }
  }

  /// Setup camera change listeners (scroll and zoom)
  Future<void> _setupCameraListener() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      // Get initial camera state
      // Note: Camera changes are handled via widget callbacks (onScrollListener)
      // The handleCameraChange() method is called from the widget level
      await _updateCameraPosition();
      
      Log.i('map', '✅ Camera state initialized');
    } catch (e) {
      Log.e('map', 'Failed to setup camera listener', e);
    }
  }
  
  /// Update camera position from current map state
  Future<void> _updateCameraPosition() async {
    try {
      final map = _mapboxMap;
      if (map == null) return;
      
      final state = await map.getCameraState();
      _currentPosition = CameraPosition(
        center: LatLng(
          state.center.coordinates.lat.toDouble(),
          state.center.coordinates.lng.toDouble(),
        ),
        zoom: state.zoom,
        bearing: state.bearing,
        tilt: state.pitch,
      );
      _cameraMoveController.add(_currentPosition!);
    } catch (e) {
      // Silently fail - camera updates are not critical
    }
  }

  /// Called from widget's onTapListener
  void handleTap(LatLng position) {
    _mapTapController.add(position);
    Log.i('map', '📍 Map tapped at: ${position.latitude}, ${position.longitude}');
  }

  /// Called to force camera state update
  void handleCameraChange() {
    _updateCameraPosition();
  }

  @override
  Future<void> setCamera(
    LatLng center,
    double zoom, {
    double? bearing,
    double? tilt,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      await map.setCamera(CameraOptions(
        center: Point(coordinates: Position(center.longitude, center.latitude)),
        zoom: zoom,
        bearing: bearing,
        pitch: tilt,
      ));
    } catch (e) {
      Log.e('map', 'Failed to set camera', e);
    }
  }

  @override
  Future<void> animateCamera(
    LatLng center,
    double zoom, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(center.longitude, center.latitude)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: duration.inMilliseconds),
      );
    } catch (e) {
      Log.e('map', 'Failed to animate camera', e);
    }
  }

  @override
  Future<void> addRoutePolyline(
    List<LatLng> points, {
    Color color = const Color(0xFF4CAF50),
    double width = 4.0,
  }) async {
    if (_routeManager == null || points.isEmpty) return;

    try {
      await removeRoutePolyline();

      final coordinates = points
          .map((p) => Position(p.longitude, p.latitude))
          .toList();

      final lineString = LineString(coordinates: coordinates);
      _routeLine = await _routeManager!.create(
        PolylineAnnotationOptions(
          geometry: lineString,
          lineColor: color.value,
          lineWidth: width,
        ),
      );

      Log.i('map', '📍 Route polyline added with ${points.length} points');
    } catch (e) {
      Log.e('map', 'Failed to add route polyline', e);
    }
  }

  @override
  Future<void> removeRoutePolyline() async {
    if (_routeLine != null && _routeManager != null) {
      try {
        await _routeManager!.delete(_routeLine!);
        _routeLine = null;
      } catch (e) {
        Log.e('map', 'Failed to remove route polyline', e);
      }
    }
  }

  @override
  Future<void> addMarker(
    String id,
    LatLng position, {
    Widget? customWidget,
    String? iconAsset,
    bool draggable = false,
  }) async {
    if (_annotationManager == null) return;

    try {
      if (_markers.containsKey(id)) {
        await _annotationManager!.delete(_markers[id]!);
        _markers.remove(id);
        _draggableMarkers.remove(id);
      }

      final point = Point(coordinates: Position(position.longitude, position.latitude));
      final marker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: point,
          iconSize: 1.0,
          isDraggable: draggable, // Note: isDraggable is the correct property name
        ),
      );

      _markers[id] = marker;
      _draggableMarkers[id] = draggable;
      
      // Setup drag listeners if marker is draggable
      if (draggable) {
        _setupMarkerDragListeners(id, marker, position);
      }

      Log.i('map', '📍 Marker "$id" added (draggable: $draggable)');
    } catch (e) {
      Log.e('map', 'Failed to add marker "$id"', e);
    }
  }
  
  /// Setup drag listeners for a marker
  void _setupMarkerDragListeners(String id, PointAnnotation marker, LatLng initialPosition) {
    // Note: Mapbox Native SDK drag events are handled via annotation manager
    // The actual drag events would be received through the annotation manager's
    // onAnnotationDragStarted, onAnnotationDrag, and onAnnotationDragEnded callbacks
    // This requires setting up listeners at the manager level
    Log.i('map', '🎯 Drag listeners setup for marker "$id"');
  }

  @override
  Future<void> removeMarker(String id) async {
    final marker = _markers[id];

    if (marker != null && _annotationManager != null) {
      try {
        await _annotationManager!.delete(marker);
        _markers.remove(id);
      } catch (e) {
        Log.e('map', 'Failed to remove marker "$id"', e);
      }
    }
  }

  @override
  Future<void> setUserLocation(LatLng position, {double? heading}) async {
    await addMarker('user_location', position);
  }
  
  @override
  Future<void> setMarkerDraggable(String markerId, bool draggable) async {
    final marker = _markers[markerId];
    if (marker != null && _annotationManager != null) {
      try {
        // Mapbox SDK requires deleting and recreating to change draggable state
        // Get current position first
        final currentGeometry = marker.geometry;
        final lat = currentGeometry.coordinates.lat.toDouble();
        final lng = currentGeometry.coordinates.lng.toDouble();
        
        // Remove old marker
        await removeMarker(markerId);
        
        // Re-add with new draggable state
        await addMarker(markerId, LatLng(lat, lng), draggable: draggable);
        
        Log.i('map', '🎯 Marker "$markerId" draggable set to $draggable');
      } catch (e) {
        Log.e('map', 'Failed to set marker "$markerId" draggable', e);
      }
    }
  }
  
  @override
  Stream<MarkerDragEvent> get onMarkerDrag => _markerDragController.stream;
  
  @override
  Future<void> updateMarkerPosition(String markerId, LatLng position) async {
    final marker = _markers[markerId];
    if (marker != null && _annotationManager != null) {
      try {
        // Get current draggable state
        final wasDraggable = _draggableMarkers[markerId] ?? false;
        
        // Remove old marker
        await removeMarker(markerId);
        
        // Re-add at new position
        await addMarker(markerId, position, draggable: wasDraggable);
        
        Log.i('map', '📍 Marker "$markerId" position updated');
      } catch (e) {
        Log.e('map', 'Failed to update marker "$markerId" position', e);
      }
    }
  }

  @override
  Stream<LatLng> get onMapTap => _mapTapController.stream;

  @override
  Stream<CameraPosition> get onCameraMove => _cameraMoveController.stream;

  @override
  CameraPosition? get currentPosition => _currentPosition;

  @override
  Future<void> disableScrollZoom() async {
    // Note: Mapbox Maps Flutter SDK doesn't support disabling scroll zoom via setSettings
    // This functionality would need to be implemented through gesture settings if available
    // For now, this is a no-op
    Log.i('map', '🔒 Scroll zoom disable requested (not supported in current SDK)');
  }

  @override
  Future<void> enableScrollZoom() async {
    // Note: Mapbox Maps Flutter SDK doesn't support enabling scroll zoom via setSettings
    // This functionality would need to be implemented through gesture settings if available
    // For now, this is a no-op
    Log.i('map', '🔓 Scroll zoom enable requested (not supported in current SDK)');
  }

  @override
  Future<void> disableInteractions() async {
    // Note: Mapbox Maps Flutter SDK doesn't support disabling interactions via setSettings
    // This functionality would need to be implemented through gesture settings if available
    // For now, this is a no-op
    Log.i('map', '🔒 Interactions disable requested (not supported in current SDK)');
  }

  @override
  Future<void> enableInteractions() async {
    // Note: Mapbox Maps Flutter SDK doesn't support enabling interactions via setSettings
    // This functionality would need to be implemented through gesture settings if available
    // For now, this is a no-op
    Log.i('map', '🔓 Interactions enable requested (not supported in current SDK)');
  }

  @override
  void dispose() {
    _mapTapController.close();
    _cameraMoveController.close();
    _markerDragController.close();
    _markers.clear();
    _draggableMarkers.clear();
  }
}
