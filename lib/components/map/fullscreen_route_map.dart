import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/poi_service.dart';
import 'package:waypoint/utils/logger.dart';

/// Full-screen route builder map
/// Allows editing routes and managing waypoints
class FullscreenRouteMap extends StatefulWidget {
  final DayItinerary day;
  final Function(DayItinerary) onDayUpdated;
  final bool isEditMode;

  const FullscreenRouteMap({
    super.key,
    required this.day,
    required this.onDayUpdated,
    this.isEditMode = true,
  });

  @override
  State<FullscreenRouteMap> createState() => _FullscreenRouteMapState();
}

class _FullscreenRouteMapState extends State<FullscreenRouteMap> {
  final fm.MapController _mapController = fm.MapController();
  bool _mapReady = false;
  List<POI> _osmPOIs = [];
  bool _loadingPOIs = false;
  
  // Selected POI types to display
  final Set<POIType> _selectedPOITypes = {
    POIType.campsite,
    POIType.hut,
    POIType.viewpoint,
    POIType.water,
    POIType.shelter,
    POIType.parking,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onMapReady();
      }
    });
  }

  void _onMapReady() {
    if (_mapReady) return;
    setState(() => _mapReady = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fitBounds();
        _loadPOIs();
      }
    });
  }

  void _fitBounds() {
    if (!_mapReady || !mounted) return;
    
    final bounds = <ll.LatLng>[];

    // Add route geometry points
    final routePoints = _parseRouteCoordinates();
    if (routePoints.isNotEmpty) {
      bounds.addAll(routePoints);
    }

    // Add start/end points
    if (widget.day.startLat != null && widget.day.startLng != null) {
      bounds.add(ll.LatLng(widget.day.startLat!, widget.day.startLng!));
    }
    if (widget.day.endLat != null && widget.day.endLng != null) {
      bounds.add(ll.LatLng(widget.day.endLat!, widget.day.endLng!));
    }

    // Add all waypoints
    if (widget.day.route != null) {
      for (final wpJson in widget.day.route!.poiWaypoints) {
        try {
          if (wpJson is Map<String, dynamic> && 
              wpJson['position'] != null &&
              wpJson['position']['lat'] != null && 
              wpJson['position']['lng'] != null) {
            final wp = RouteWaypoint.fromJson(wpJson);
            bounds.add(wp.position);
          }
        } catch (_) {}
      }
    }

    if (bounds.isEmpty) return;

    double minLat = bounds.first.latitude;
    double maxLat = bounds.first.latitude;
    double minLng = bounds.first.longitude;
    double maxLng = bounds.first.longitude;

    for (final point in bounds) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    final center = ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 13;
    if (maxDiff > 0.5) {
      zoom = 10;
    } else if (maxDiff > 0.2) {
      zoom = 11;
    } else if (maxDiff > 0.1) {
      zoom = 12;
    }

    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  Future<void> _loadPOIs() async {
    if (_loadingPOIs || !_mapReady) return;
    
    setState(() => _loadingPOIs = true);
    
    try {
      // Get map bounds
      final bounds = _mapController.camera.visibleBounds;
      
      final pois = await POIService.fetchPOIs(
        southWest: ll.LatLng(bounds.south, bounds.west),
        northEast: ll.LatLng(bounds.north, bounds.east),
        poiTypes: _selectedPOITypes.toList(),
        maxResults: 200,
      );
      
      if (mounted) {
        setState(() {
          _osmPOIs = pois;
          _loadingPOIs = false;
        });
        Log.i('map', 'Loaded ${pois.length} OSM POIs');
      }
    } catch (e) {
      Log.e('map', 'Failed to load POIs', e);
      if (mounted) {
        setState(() => _loadingPOIs = false);
      }
    }
  }

  List<ll.LatLng> _parseRouteCoordinates() {
    final geometry = widget.day.route?.geometry;
    if (geometry == null) return [];

    final coords = geometry['coordinates'] as List?;
    if (coords == null || coords.isEmpty) return [];

    final points = <ll.LatLng>[];
    for (final c in coords) {
      try {
        if (c is List && c.length >= 2) {
          final lng = (c[0] as num?)?.toDouble();
          final lat = (c[1] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(ll.LatLng(lat, lng));
          }
        } else if (c is Map) {
          final lat = (c['lat'] as num?)?.toDouble();
          final lng = (c['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(ll.LatLng(lat, lng));
          }
        }
      } catch (_) {}
    }
    
    return points;
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    ll.LatLng initialCenter = ll.LatLng(68.35, 18.83);
    if (widget.day.startLat != null && widget.day.startLng != null) {
      if (widget.day.endLat != null && widget.day.endLng != null) {
        initialCenter = ll.LatLng(
          (widget.day.startLat! + widget.day.endLat!) / 2,
          (widget.day.startLng! + widget.day.endLng!) / 2,
        );
      } else {
        initialCenter = ll.LatLng(widget.day.startLat!, widget.day.startLng!);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          fm.FlutterMap(
            mapController: _mapController,
            options: fm.MapOptions(
              initialCenter: initialCenter,
              initialZoom: 12,
              interactionOptions: const fm.InteractionOptions(
                flags: fm.InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
              ),
              onPositionChanged: (position, hasGesture) {
                // Reload POIs when map moves significantly
                if (hasGesture) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !_loadingPOIs) {
                      _loadPOIs();
                    }
                  });
                }
              },
            ),
            children: [
              // Map tiles - using custom Mapbox style
              fm.TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/thomascortebeeck93/cmkv0yv7a006401s9akepciwf/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
                userAgentPackageName: 'com.waypoint.app',
              ),
              // Route line
              if (widget.day.route?.geometry != null) _buildRoutePolyline(),
              // Markers
              fm.MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildTopButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.pop(),
                    ),
                    const Spacer(),
                    if (widget.isEditMode)
                      _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),

          // Right side controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 12,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.fit_screen,
                  onTap: _fitBounds,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.add,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove,
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.refresh,
                  onTap: _loadPOIs,
                  isLoading: _loadingPOIs,
                ),
              ],
            ),
          ),

          // POI type filters (left side)
          if (widget.isEditMode)
            Positioned(
              left: 12,
              top: MediaQuery.of(context).padding.top + 80,
              child: _buildPOIFilters(),
            ),
        ],
      ),
    );
  }

  Widget _buildRoutePolyline() {
    final points = _parseRouteCoordinates();
    if (points.isEmpty) return const SizedBox.shrink();

    return fm.PolylineLayer(
      polylines: [
        fm.Polyline(
          points: points,
          strokeWidth: 4,
          color: const Color(0xFF4CAF50),
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      ],
    );
  }

  List<fm.Marker> _buildMarkers() {
    final markers = <fm.Marker>[];

    // Start marker (A) - 40px, distinct from POIs
    if (widget.day.startLat != null && widget.day.startLng != null) {
      markers.add(
        fm.Marker(
          point: ll.LatLng(widget.day.startLat!, widget.day.startLng!),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF52B788),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // End marker (B) - 40px, distinct from POIs
    if (widget.day.endLat != null && widget.day.endLng != null) {
      markers.add(
        fm.Marker(
          point: ll.LatLng(widget.day.endLat!, widget.day.endLng!),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD62828),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // OSM POI markers (subtle, background context)
    for (final poi in _osmPOIs) {
      markers.add(
        fm.Marker(
          point: poi.coordinates,
          width: 24,
          height: 24,
          child: GestureDetector(
            onTap: () => _showPOIDetails(poi),
            child: _buildOSMPOIMarker(poi),
          ),
        ),
      );
    }

    // Custom waypoint markers (bold, prominent - USER'S PLAN)
    if (widget.day.route != null) {
      for (final wpJson in widget.day.route!.poiWaypoints) {
        try {
          if (wpJson is Map<String, dynamic> && 
              wpJson['position'] != null &&
              wpJson['position']['lat'] != null && 
              wpJson['position']['lng'] != null) {
            final wp = RouteWaypoint.fromJson(wpJson);
            markers.add(
              fm.Marker(
                point: wp.position,
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => _showWaypointDetails(wp),
                  child: _buildCustomWaypointMarker(wp),
                ),
              ),
            );
          }
        } catch (_) {}
      }
    }

    return markers;
  }

  Widget _buildTopButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: Save changes
        context.pop();
      },
      icon: const Icon(Icons.check, size: 18),
      label: const Text('Save'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  Widget _buildPOIFilters() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 80),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'POIs',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...POIType.values.take(10).map((type) {
            final isSelected = _selectedPOITypes.contains(type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPOITypes.remove(type);
                    } else {
                      _selectedPOITypes.add(type);
                    }
                  });
                  _loadPOIs();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? type.color : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? type.color : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    type.icon,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build minimalistic OSM POI marker (subtle, background context)
  Widget _buildOSMPOIMarker(POI poi) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: poi.type.color.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        poi.type.icon,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  /// Build bold Custom Waypoint marker (prominent, core feature)
  Widget _buildCustomWaypointMarker(RouteWaypoint waypoint) {
    final waypointColor = getWaypointColor(waypoint.type);
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: waypointColor,
          width: 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: waypointColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        getWaypointIcon(waypoint.type),
        color: waypointColor,
        size: 20,
      ),
    );
  }

  void _showPOIDetails(POI poi) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: poi.type.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(poi.type.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${poi.type.displayName} (OSM)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (poi.description != null) ...[
              const SizedBox(height: 16),
              Text(
                poi.description!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '${poi.coordinates.latitude.toStringAsFixed(5)}, ${poi.coordinates.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWaypointDetails(RouteWaypoint waypoint) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: getWaypointColor(waypoint.type),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getWaypointIcon(waypoint.type),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waypoint.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        getWaypointLabel(waypoint.type),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (waypoint.description != null) ...[
              const SizedBox(height: 16),
              Text(
                waypoint.description!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '${waypoint.position.latitude.toStringAsFixed(5)}, ${waypoint.position.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
