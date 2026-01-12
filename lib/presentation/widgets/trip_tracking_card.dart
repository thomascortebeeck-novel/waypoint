import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/integrations/mapbox_config.dart';

/// A compact map card that shows a route between two points and the
/// user's live location as a puck. Uses FlutterMap so it renders in
/// Dreamflow; on device you may swap to Mapbox MapWidget if desired.
class TripTrackingCard extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final double height;
  const TripTrackingCard({super.key, required this.start, required this.end, this.height = 220});

  @override
  State<TripTrackingCard> createState() => _TripTrackingCardState();
}

class _TripTrackingCardState extends State<TripTrackingCard> {
  Position? _position;
  StreamSubscription<Position>? _sub;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // We won't prompt here; just show disabled state.
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() => _permissionDenied = true);
        return;
      }
      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
      ).listen((pos) => setState(() => _position = pos));
      final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (mounted) setState(() => _position = current);
    } catch (e) {
      debugPrint('TripTrackingCard location error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng((widget.start.latitude + widget.end.latitude) / 2, (widget.start.longitude + widget.end.longitude) / 2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
                userAgentPackageName: 'com.waypoint.app',
              ),
              PolylineLayer(polylines: [
                Polyline(points: [widget.start, widget.end], strokeWidth: 4, color: Colors.green),
              ]),
              MarkerLayer(markers: [
                Marker(point: widget.start, width: 30, height: 30, child: _dot(context, Colors.green)),
                Marker(point: widget.end, width: 30, height: 30, child: _dot(context, Colors.green)),
                if (_position != null)
                  Marker(
                    point: LatLng(_position!.latitude, _position!.longitude),
                    width: 34,
                    height: 34,
                    child: _puck(context),
                  ),
              ]),
            ],
          ),
          if (_permissionDenied)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _PermissionBanner(onGrant: () async {
                setState(() => _permissionDenied = false);
                await _initLocation();
              }),
            ),
        ]),
      ),
    );
  }

  Widget _puck(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
        child: const Icon(Icons.navigation, color: Colors.white, size: 16),
      );

  Widget _dot(BuildContext context, Color color) => Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      );
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          const Icon(Icons.location_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Location permission required to track your progress.', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: onGrant, child: const Text('Grant', style: TextStyle(color: Colors.white)))
        ]),
      ),
    );
  }
}
