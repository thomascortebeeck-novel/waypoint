// Mobile implementation of Google Maps
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps_mobile;
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/utils/logger.dart';

/// Google Maps widget for mobile platforms (iOS/Android)
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
  State<GoogleMapWidget> createState() => _GoogleMapWidgetMobileState();
}

class _GoogleMapWidgetMobileState extends State<GoogleMapWidget> {
  gmaps_mobile.GoogleMapController? _mapController;
  final Set<gmaps_mobile.Marker> _markers = {};
  final Set<gmaps_mobile.Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
    _updatePolylines();
  }

  @override
  void didUpdateWidget(GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.annotations != widget.annotations) {
      _updateMarkers();
    }
    if (oldWidget.polylines != widget.polylines) {
      _updatePolylines();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    _markers.clear();
    for (final annotation in widget.annotations) {
      _markers.add(
        gmaps_mobile.Marker(
          markerId: gmaps_mobile.MarkerId(annotation.id),
          position: gmaps_mobile.LatLng(
            annotation.position.latitude,
            annotation.position.longitude,
          ),
          icon: gmaps_mobile.BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(annotation.color),
          ),
          infoWindow: annotation.showInfoWindow && annotation.label != null
              ? gmaps_mobile.InfoWindow(title: annotation.label!)
              : gmaps_mobile.InfoWindow.noText,
          draggable: annotation.draggable,
          onTap: () => annotation.onTap?.call(),
          onDragEnd: annotation.onDrag != null
              ? (gmaps_mobile.LatLng position) => annotation.onDrag!(
                    ll.LatLng(position.latitude, position.longitude),
                  )
              : null,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  void _updatePolylines() {
    _polylines.clear();
    for (final polyline in widget.polylines) {
      _polylines.add(
        gmaps_mobile.Polyline(
          polylineId: gmaps_mobile.PolylineId(polyline.id),
          points: polyline.points
              .map((p) => gmaps_mobile.LatLng(p.latitude, p.longitude))
              .toList(),
          color: polyline.color,
          width: polyline.width.toInt(),
          patterns: polyline.borderColor != null
              ? <gmaps_mobile.PatternItem>[gmaps_mobile.PatternItem.dash(10), gmaps_mobile.PatternItem.gap(5)]
              : <gmaps_mobile.PatternItem>[],
        ),
      );
    }
    if (mounted) setState(() {});
  }

  double _getMarkerHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  Future<void> _onMapCreated(gmaps_mobile.GoogleMapController controller) async {
    _mapController = controller;

    final waypointController = _GoogleMapControllerMobile(
      controller: controller,
      onCameraChanged: widget.onCameraChanged,
    );

    widget.onMapCreated?.call(waypointController);
    Log.i('google_map', '✅ Google Maps created successfully (mobile)');
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.configuration ?? MapConfiguration.mainMap();
    
    return Stack(
      children: [
        gmaps_mobile.GoogleMap(
          initialCameraPosition: gmaps_mobile.CameraPosition(
            target: gmaps_mobile.LatLng(
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
          onTap: widget.onTap != null
              ? (gmaps_mobile.LatLng position) => widget.onTap!(
                    ll.LatLng(position.latitude, position.longitude),
                  )
              : null,
          onLongPress: widget.onLongPress != null
              ? (gmaps_mobile.LatLng position) => widget.onLongPress!(
                    ll.LatLng(position.latitude, position.longitude),
                  )
              : null,
          mapType: gmaps_mobile.MapType.normal,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: config.initialTilt > 0,
          rotateGesturesEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
        ...widget.overlays,
      ],
    );
  }
}

/// Mobile implementation of WaypointMapController
class _GoogleMapControllerMobile implements WaypointMapController {
  final gmaps_mobile.GoogleMapController controller;
  final Function(CameraPosition)? onCameraChanged;
  final _markerDragController = StreamController<MarkerDragEvent>.broadcast();
  final _mapTapController = StreamController<ll.LatLng>.broadcast();
  final _cameraMoveController = StreamController<CameraPosition>.broadcast();
  
  final Map<String, gmaps_mobile.Marker> _markers = {};
  final Map<String, gmaps_mobile.Polyline> _polylines = {};
  bool _interactionsEnabled = true;

  _GoogleMapControllerMobile({
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
      gmaps_mobile.CameraUpdate.newCameraPosition(
        gmaps_mobile.CameraPosition(
          target: gmaps_mobile.LatLng(center.latitude, center.longitude),
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
      gmaps_mobile.CameraUpdate.newCameraPosition(
        gmaps_mobile.CameraPosition(
          target: gmaps_mobile.LatLng(center.latitude, center.longitude),
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
    _markers[id] = gmaps_mobile.Marker(
      markerId: gmaps_mobile.MarkerId(id),
      position: gmaps_mobile.LatLng(position.latitude, position.longitude),
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
      _markers[markerId] = gmaps_mobile.Marker(
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
      _markers[markerId] = gmaps_mobile.Marker(
        markerId: marker.markerId,
        position: gmaps_mobile.LatLng(position.latitude, position.longitude),
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

