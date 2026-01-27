import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';

/// Stub widget for non-web platforms
/// This should never be used - AdaptiveMapWidget should use Mapbox SDK on mobile
class MapboxWebWidget extends StatelessWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final void Function(WaypointMapController)? onMapCreated;

  const MapboxWebWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be displayed on mobile
    return Container(
      color: Colors.red.shade100,
      child: const Center(
        child: Text('Error: Web map widget used on non-web platform'),
      ),
    );
  }
}
