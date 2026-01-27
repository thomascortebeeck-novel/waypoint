import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:waypoint/features/map/vector_map_controller.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/features/map/web/mapbox_web_widget_export.dart';
import 'package:waypoint/integrations/mapbox_config.dart';

/// Adaptive map widget that uses the best rendering engine per platform:
/// - Mobile (iOS/Android): Mapbox SDK with native vector tiles + 3D terrain
/// - Web: Mapbox GL JS with the SAME custom style as mobile
///
/// Both platforms use the same Mapbox style for visual consistency!
class AdaptiveMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final void Function(WaypointMapController)? onMapCreated;
  final List<Widget> overlays;

  const AdaptiveMapWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12.0,
    this.initialTilt = 0.0,
    this.initialBearing = 0.0,
    this.onMapCreated,
    this.overlays = const [],
  });

  @override
  State<AdaptiveMapWidget> createState() => _AdaptiveMapWidgetState();
}

class _AdaptiveMapWidgetState extends State<AdaptiveMapWidget> {
  VectorMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map layer - platform specific
        if (kIsWeb)
          _buildWebMap()
        else
          _buildMobileMap(),
        
        // Overlays (controls, tracking, etc.)
        ...widget.overlays,
      ],
    );
  }

  /// Build mobile map using native Mapbox SDK
  /// Full 3D terrain, custom style, offline support via TileStore
  Widget _buildMobileMap() {
    return MapWidget(
      key: const ValueKey('mapbox_map'),
      styleUri: mapboxStyleUri,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            widget.initialCenter.longitude,
            widget.initialCenter.latitude,
          ),
        ),
        zoom: widget.initialZoom,
        bearing: widget.initialBearing,
        pitch: widget.initialTilt,
      ),
      onMapCreated: (MapboxMap map) {
        _controller = VectorMapController();
        _controller!.initialize(map);
        widget.onMapCreated?.call(_controller!);
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
  Widget _buildWebMap() {
    return MapboxWebWidget(
      initialCenter: widget.initialCenter,
      initialZoom: widget.initialZoom,
      initialTilt: widget.initialTilt,
      initialBearing: widget.initialBearing,
      onMapCreated: widget.onMapCreated,
    );
  }
}
