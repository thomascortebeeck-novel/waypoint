import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Unified map controller interface that works with both vector and raster maps
/// This abstraction allows seamless switching between online (vector) and offline (raster) modes
abstract class WaypointMapController {
  /// Set camera position and zoom level
  Future<void> setCamera(
    LatLng center,
    double zoom, {
    double? bearing,
    double? tilt,
  });

  /// Animate camera to new position
  Future<void> animateCamera(
    LatLng center,
    double zoom, {
    Duration duration = const Duration(milliseconds: 500),
  });

  /// Add or update route polyline on map
  Future<void> addRoutePolyline(
    List<LatLng> points, {
    Color color = const Color(0xFF4CAF50),
    double width = 4.0,
  });

  /// Remove route polyline from map
  Future<void> removeRoutePolyline();

  /// Add marker to map
  Future<void> addMarker(
    String id,
    LatLng position, {
    Widget? customWidget,
    String? iconAsset,
    bool draggable = false,
  });

  /// Remove marker from map
  Future<void> removeMarker(String id);

  /// Set user location indicator
  Future<void> setUserLocation(
    LatLng position, {
    double? heading,
  });
  
  /// Make a marker draggable (for route building)
  Future<void> setMarkerDraggable(String markerId, bool draggable);
  
  /// Listen to marker drag events
  Stream<MarkerDragEvent> get onMarkerDrag;
  
  /// Update marker position programmatically
  Future<void> updateMarkerPosition(String markerId, LatLng position);

  /// Stream of map tap events
  Stream<LatLng> get onMapTap;

  /// Stream of camera position changes
  Stream<CameraPosition> get onCameraMove;

  /// Get current camera position
  CameraPosition? get currentPosition;

  /// Disable scroll zoom on the map (e.g., when a modal is open)
  Future<void> disableScrollZoom();

  /// Enable scroll zoom on the map (e.g., when a modal closes)
  Future<void> enableScrollZoom();

  /// Dispose resources
  void dispose();
}

/// Camera position data
class CameraPosition {
  final LatLng center;
  final double zoom;
  final double bearing;
  final double tilt;

  const CameraPosition({
    required this.center,
    required this.zoom,
    this.bearing = 0,
    this.tilt = 0,
  });
}

/// Marker drag event data
class MarkerDragEvent {
  final String markerId;
  final LatLng position;
  final MarkerDragState state;
  
  const MarkerDragEvent({
    required this.markerId,
    required this.position,
    required this.state,
  });
}

/// Marker drag states
enum MarkerDragState {
  /// Drag started
  dragStart,
  
  /// Dragging in progress
  drag,
  
  /// Drag ended
  dragEnd,
}
