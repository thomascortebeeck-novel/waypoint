import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/services/poi_service.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/components/map/waypoint_map_legend.dart';

/// Full-screen route map viewer (read-only)
/// Uses AdaptiveMapWidget with Mapbox rendering for beautiful visuals
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
  WaypointMapController? _mapController;
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
  }

  void _onMapReady() {
    if (_mapReady || _mapController == null) return;
    setState(() => _mapReady = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _addMapData();
        _fitBounds();
        _loadPOIs();
      }
    });
  }

  /// Add route and markers to the map using the controller API
  Future<void> _addMapData() async {
    if (_mapController == null) return;

    // Add route polyline
    final routePoints = _parseRouteCoordinates();
    if (routePoints.isNotEmpty) {
      await _mapController!.addRoutePolyline(
        routePoints,
        color: const Color(0xFF4CAF50),
        width: 4.0,
      );
    }

    // Add start marker
    if (widget.day.startLat != null && widget.day.startLng != null) {
      await _mapController!.addMarker(
        'start',
        ll.LatLng(widget.day.startLat!, widget.day.startLng!),
      );
    }

    // Add end marker
    if (widget.day.endLat != null && widget.day.endLng != null) {
      await _mapController!.addMarker(
        'end',
        ll.LatLng(widget.day.endLat!, widget.day.endLng!),
      );
    }

    // Add waypoint markers
    if (widget.day.route != null) {
      for (final wpJson in widget.day.route!.poiWaypoints) {
        try {
          if (wpJson is Map<String, dynamic> && 
              wpJson['position'] != null &&
              wpJson['position']['lat'] != null && 
              wpJson['position']['lng'] != null) {
            final wp = RouteWaypoint.fromJson(wpJson);
            await _mapController!.addMarker(
              'waypoint_${wp.name}',
              wp.position,
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _fitBounds() async {
    if (!_mapReady || !mounted || _mapController == null) return;
    
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
      await _mapController!.animateCamera(center, zoom);
    } catch (_) {}
  }

  Future<void> _loadPOIs() async {
    if (_loadingPOIs || !_mapReady || _mapController == null) return;
    
    setState(() => _loadingPOIs = true);
    
    try {
      // Get visible bounds from current camera position
      final currentPos = _mapController!.currentPosition;
      if (currentPos == null) {
        setState(() => _loadingPOIs = false);
        return;
      }

      // Calculate approximate bounds based on zoom level
      final center = currentPos.center;
      final zoom = currentPos.zoom;
      final latOffset = 0.1 / zoom;
      final lngOffset = 0.1 / zoom;
      
      final pois = await POIService.fetchPOIs(
        southWest: ll.LatLng(center.latitude - latOffset, center.longitude - lngOffset),
        northEast: ll.LatLng(center.latitude + latOffset, center.longitude + lngOffset),
        poiTypes: _selectedPOITypes.toList(),
        maxResults: 200,
      );
      
      if (mounted) {
        setState(() {
          _osmPOIs = pois;
          _loadingPOIs = false;
        });
        
        // Add POI markers to map
        for (final poi in pois) {
          await _mapController!.addMarker(
            'poi_${poi.id}',
            poi.coordinates,
          );
        }
        
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

  Future<void> _zoomIn() async {
    if (_mapController == null) return;
    final currentPos = _mapController!.currentPosition;
    if (currentPos == null) return;
    await _mapController!.animateCamera(currentPos.center, currentPos.zoom + 1);
  }

  Future<void> _zoomOut() async {
    if (_mapController == null) return;
    final currentPos = _mapController!.currentPosition;
    if (currentPos == null) return;
    await _mapController!.animateCamera(currentPos.center, currentPos.zoom - 1);
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

    final mapConfig = MapConfiguration.mainMap(
      styleUri: mapboxStyleUri,
      rasterTileUrl: defaultRasterTileUrl,
      enable3DTerrain: true,
      initialZoom: 12.0,
    );

    return Scaffold(
      body: AdaptiveMapWidget(
        initialCenter: initialCenter,
        configuration: mapConfig,
        onMapCreated: (controller) {
          _mapController = controller;
          _onMapReady();
        },
        overlays: [
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

          // Map legend overlay (bottom-left)
          Positioned(
            bottom: 16,
            left: 16,
            child: const WaypointMapLegend(),
          ),
        ],
      ),
    );
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
}
