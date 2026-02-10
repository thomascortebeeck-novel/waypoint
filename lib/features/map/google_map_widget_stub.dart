// Stub implementation for non-web platforms (mobile)
// This file is replaced by google_map_widget_web.dart on web via conditional export

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';

/// Stub implementation - should not be used
/// Use google_map_widget_export.dart which conditionally exports the correct implementation
class GoogleMapWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // This should never be called - use conditional export
    throw UnimplementedError('GoogleMapWidget stub - use conditional export');
  }
}

