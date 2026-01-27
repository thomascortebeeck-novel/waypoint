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
  CameraPosition? _currentPosition;
  
  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _markers = {};
  
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
  }) async {
    if (_annotationManager == null) return;

    try {
      if (_markers.containsKey(id)) {
        await _annotationManager!.delete(_markers[id]!);
        _markers.remove(id);
      }

      final point = Point(coordinates: Position(position.longitude, position.latitude));
      final marker = await _annotationManager!.create(
        PointAnnotationOptions(
          geometry: point,
          iconSize: 1.0,
        ),
      );

      _markers[id] = marker;
      Log.i('map', '📍 Marker "$id" added');
    } catch (e) {
      Log.e('map', 'Failed to add marker "$id"', e);
    }
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
  Stream<LatLng> get onMapTap => _mapTapController.stream;

  @override
  Stream<CameraPosition> get onCameraMove => _cameraMoveController.stream;

  @override
  CameraPosition? get currentPosition => _currentPosition;

  @override
  void dispose() {
    _mapTapController.close();
    _cameraMoveController.close();
    _markers.clear();
  }
}
