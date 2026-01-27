import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';

/// Web-specific map controller using MapLibre GL JS
/// This is a stub that communicates with JavaScript via platform channels
class WebMapController extends WaypointMapController {
  final _mapTapController = StreamController<LatLng>.broadcast();
  final _cameraMoveController = StreamController<CameraPosition>.broadcast();
  CameraPosition? _currentPosition;
  
  // JavaScript interop function references
  // These will be set up when the map is initialized
  Function(double lat, double lng, double zoom)? _jsSetCamera;
  Function(double lat, double lng, double zoom, int durationMs)? _jsFlyTo;
  Function(List<List<double>> coordinates, int color, double width)? _jsAddRoute;
  Function()? _jsRemoveRoute;
  Function(String id, double lat, double lng)? _jsAddMarker;
  Function(String id)? _jsRemoveMarker;

  /// Initialize controller with JavaScript interop functions
  void initialize({
    required Function(double lat, double lng, double zoom) setCamera,
    required Function(double lat, double lng, double zoom, int durationMs) flyTo,
    required Function(List<List<double>> coordinates, int color, double width) addRoute,
    required Function() removeRoute,
    required Function(String id, double lat, double lng) addMarker,
    required Function(String id) removeMarker,
    required CameraPosition initialPosition,
  }) {
    _jsSetCamera = setCamera;
    _jsFlyTo = flyTo;
    _jsAddRoute = addRoute;
    _jsRemoveRoute = removeRoute;
    _jsAddMarker = addMarker;
    _jsRemoveMarker = removeMarker;
    _currentPosition = initialPosition;
  }

  /// Called from JavaScript when map is tapped
  void onMapTapped(double lat, double lng) {
    final position = LatLng(lat, lng);
    _mapTapController.add(position);
  }

  /// Called from JavaScript when camera moves
  void onCameraChanged(double lat, double lng, double zoom, double bearing, double pitch) {
    _currentPosition = CameraPosition(
      center: LatLng(lat, lng),
      zoom: zoom,
      bearing: bearing,
      tilt: pitch,
    );
    _cameraMoveController.add(_currentPosition!);
  }

  @override
  Future<void> setCamera(
    LatLng center,
    double zoom, {
    double? bearing,
    double? tilt,
  }) async {
    _jsSetCamera?.call(center.latitude, center.longitude, zoom);
    _currentPosition = CameraPosition(
      center: center,
      zoom: zoom,
      bearing: bearing ?? 0,
      tilt: tilt ?? 0,
    );
  }

  @override
  Future<void> animateCamera(
    LatLng center,
    double zoom, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    _jsFlyTo?.call(center.latitude, center.longitude, zoom, duration.inMilliseconds);
  }

  @override
  Future<void> addRoutePolyline(
    List<LatLng> points, {
    Color color = const Color(0xFF4CAF50),
    double width = 4.0,
  }) async {
    final coordinates = points.map((p) => [p.longitude, p.latitude]).toList();
    _jsAddRoute?.call(coordinates, color.value, width);
  }

  @override
  Future<void> removeRoutePolyline() async {
    _jsRemoveRoute?.call();
  }

  @override
  Future<void> addMarker(
    String id,
    LatLng position, {
    Widget? customWidget,
    String? iconAsset,
  }) async {
    _jsAddMarker?.call(id, position.latitude, position.longitude);
  }

  @override
  Future<void> removeMarker(String id) async {
    _jsRemoveMarker?.call(id);
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
  }
}
