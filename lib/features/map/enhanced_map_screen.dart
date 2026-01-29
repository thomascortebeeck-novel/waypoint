import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/features/map/tracking_overlay_widget.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/utils/logger.dart';

/// Enhanced map screen with vector tiles, 3D terrain, and offline support
/// Demonstrates the full capability of the adaptive map system
class EnhancedMapScreen extends StatefulWidget {
  final LatLng? initialCenter;
  final List<LatLng>? routePoints;
  final bool showRoute;

  const EnhancedMapScreen({
    super.key,
    this.initialCenter,
    this.routePoints,
    this.showRoute = false,
  });

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen> {
  WaypointMapController? _mapController;
  bool _show3DControls = true;
  double _currentZoom = 12.0;
  double _currentTilt = 0.0;
  double _currentBearing = 0.0;

  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? const LatLng(61.0, 8.5); // Norway default
  }

  void _onMapCreated(WaypointMapController controller) {
    _mapController = controller;
    Log.i('map', '🗺️ Map controller ready');

    // Add route if provided
    if (widget.showRoute && widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      controller.addRoutePolyline(widget.routePoints!);
    }

    // Listen to camera changes
    controller.onCameraMove.listen((position) {
      setState(() {
        _currentZoom = position.zoom;
        _currentTilt = position.tilt;
        _currentBearing = position.bearing;
      });
    });

    // Listen to map taps
    controller.onMapTap.listen((position) {
      Log.i('map', '📍 Map tapped at: ${position.latitude}, ${position.longitude}');
      _showLocationSheet(position);
    });
  }

  void _showLocationSheet(LatLng position) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Latitude: ${position.latitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Longitude: ${position.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _mapController?.addMarker(
                        'user_marker_${DateTime.now().millisecondsSinceEpoch}',
                        position,
                      );
                      context.pop();
                    },
                    icon: const Icon(Icons.place),
                    label: const Text('Add Marker'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _zoomIn() {
    final controller = _mapController;
    if (controller?.currentPosition != null) {
      controller!.setCamera(
        controller.currentPosition!.center,
        _currentZoom + 1,
        bearing: _currentBearing,
        tilt: _currentTilt,
      );
    }
  }

  void _zoomOut() {
    final controller = _mapController;
    if (controller?.currentPosition != null) {
      controller!.setCamera(
        controller.currentPosition!.center,
        (_currentZoom - 1).clamp(1.0, 20.0),
        bearing: _currentBearing,
        tilt: _currentTilt,
      );
    }
  }

  void _toggle3D() {
    final controller = _mapController;
    if (controller?.currentPosition != null) {
      final newTilt = _currentTilt > 0 ? 0.0 : 60.0;
      controller!.setCamera(
        controller.currentPosition!.center,
        _currentZoom,
        bearing: _currentBearing,
        tilt: newTilt,
      );
    }
  }

  void _resetBearing() {
    final controller = _mapController;
    if (controller?.currentPosition != null) {
      controller!.setCamera(
        controller.currentPosition!.center,
        _currentZoom,
        bearing: 0.0,
        tilt: _currentTilt,
      );
    }
  }

  void _centerOnRoute() {
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      final points = widget.routePoints!;
      final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      final avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
      
      _mapController?.animateCamera(
        LatLng(avgLat, avgLng),
        11.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Main Map configuration (Mapbox vector with fallback)
    final mapConfig = MapConfiguration.mainMap(
      styleUri: mapboxStyleUri,
      rasterTileUrl: defaultRasterTileUrl,
      enable3DTerrain: true,
      initialZoom: 12.0,
      initialTilt: 0.0,
    );

    return Scaffold(
      body: AdaptiveMapWidget(
        initialCenter: _center,
        configuration: mapConfig,
        onMapCreated: _onMapCreated,
        overlays: [
          // Top bar with back button and status
          _buildTopBar(),
          
          // Map controls (zoom, 3D, etc.)
          _buildMapControls(),
          
          // Camera info overlay
          if (_mapController != null) _buildCameraInfo(),
          
          // GPS Tracking overlay
          if (_mapController != null)
            TrackingOverlayWidget(
              mapController: _mapController,
              route: widget.routePoints,
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Back button
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => context.pop(),
                ),
              ),
              
              const Spacer(),
              
              // Mode indicator
              if (!kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terrain, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Vector 3D',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 80,
      child: Column(
        children: [
          // Zoom in
          _buildControlButton(
            icon: Icons.add,
            onPressed: _zoomIn,
          ),
          const SizedBox(height: 8),
          
          // Zoom out
          _buildControlButton(
            icon: Icons.remove,
            onPressed: _zoomOut,
          ),
          const SizedBox(height: 16),
          
          // 3D toggle (only on mobile)
          if (!kIsWeb) ...[
            _buildControlButton(
              icon: _currentTilt > 0 ? Icons.threed_rotation : Icons.map,
              onPressed: _toggle3D,
              isActive: _currentTilt > 0,
            ),
            const SizedBox(height: 8),
          ],
          
          // Reset bearing
          if (_currentBearing.abs() > 1) ...[
            _buildControlButton(
              icon: Icons.explore,
              onPressed: _resetBearing,
            ),
            const SizedBox(height: 8),
          ],
          
          // Center on route
          if (widget.routePoints != null) ...[
            _buildControlButton(
              icon: Icons.center_focus_strong,
              onPressed: _centerOnRoute,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.white : Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCameraInfo() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zoom: ${_currentZoom.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (!kIsWeb) ...[
              Text(
                'Tilt: ${_currentTilt.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Bearing: ${_currentBearing.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
