import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/trip_selection_model.dart';
import 'package:waypoint/services/poi_service.dart';
import 'package:waypoint/utils/logger.dart';

/// Configuration for map display modes
enum MapDisplayMode {
  /// Shows all waypoints and OSM POIs (used in builder and plan details)
  all,
  
  /// Shows only selected waypoints and OSM POIs (used in trip day view)
  selectedOnly,
}

/// A reusable map card component for displaying routes and waypoints
/// 
/// Supports two display modes:
/// - all: Shows all custom waypoints and OSM POIs
/// - selectedOnly: Shows only waypoints marked as selected (for trip participants)
class WaypointMapCard extends StatefulWidget {
  final DayItinerary day;
  final MapDisplayMode displayMode;
  final VoidCallback? onEditRoute;
  final VoidCallback? onFullScreen;
  final bool showControls;
  final bool fetchOSMPOIs;
  final double? height;
  final TripDaySelection? daySelection;
  final bool isOwner;
  
  const WaypointMapCard({
    super.key,
    required this.day,
    this.displayMode = MapDisplayMode.all,
    this.onEditRoute,
    this.onFullScreen,
    this.showControls = true,
    this.fetchOSMPOIs = false,
    this.height,
    this.daySelection,
    this.isOwner = true,
  });

  @override
  State<WaypointMapCard> createState() => _WaypointMapCardState();
}

class _WaypointMapCardState extends State<WaypointMapCard> {
  final fm.MapController _mapController = fm.MapController();
  bool _mapReady = false;
  List<POI> _osmPOIs = [];
  bool _loadingPOIs = false;

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
        if (widget.fetchOSMPOIs) {
          _loadPOIs();
        }
      }
    });
  }

  Future<void> _loadPOIs() async {
    if (_loadingPOIs || !_mapReady) return;
    
    setState(() => _loadingPOIs = true);
    Log.i('map', '🔍 Starting to load OSM POIs...');
    
    try {
      final bounds = _mapController.camera.visibleBounds;
      Log.i('map', '📍 Map bounds: S=${bounds.south.toStringAsFixed(2)}, W=${bounds.west.toStringAsFixed(2)}, N=${bounds.north.toStringAsFixed(2)}, E=${bounds.east.toStringAsFixed(2)}');
      
      // Load main outdoor POI types
      final pois = await POIService.fetchPOIs(
        southWest: ll.LatLng(bounds.south, bounds.west),
        northEast: ll.LatLng(bounds.north, bounds.east),
        poiTypes: [
          POIType.campsite,
          POIType.hut,
          POIType.viewpoint,
          POIType.water,
          POIType.shelter,
          POIType.parking,
          POIType.toilets,
        ],
        maxResults: 100,
      );
      
      if (mounted) {
        setState(() {
          _osmPOIs = pois;
          _loadingPOIs = false;
        });
        Log.i('map', '✅ Loaded ${pois.length} OSM POIs successfully');
      }
    } catch (e, stack) {
      Log.e('map', '❌ Failed to load POIs', e, stack);
      if (mounted) {
        setState(() => _loadingPOIs = false);
      }
    }
  }

  void _fitBounds() {
    if (!_mapReady || !mounted) return;
    
    final bounds = <ll.LatLng>[];

    // Add route geometry points
    final routePoints = _parseRouteCoordinates();
    if (routePoints.isNotEmpty) {
      bounds.addAll(routePoints);
    }

    // Add start/end points as fallback
    if (widget.day.startLat != null && widget.day.startLng != null) {
      bounds.add(ll.LatLng(widget.day.startLat!, widget.day.startLng!));
    }
    if (widget.day.endLat != null && widget.day.endLng != null) {
      bounds.add(ll.LatLng(widget.day.endLat!, widget.day.endLng!));
    }

    // Add waypoint positions based on display mode
    final waypoints = _getFilteredWaypoints();
    for (final wpJson in waypoints) {
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

    if (bounds.isEmpty) return;

    // Calculate bounds
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

    // Add padding
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

    double zoom = 14;
    if (maxDiff > 0.5) {
      zoom = 10;
    } else if (maxDiff > 0.2) {
      zoom = 11;
    } else if (maxDiff > 0.1) {
      zoom = 12;
    } else if (maxDiff > 0.05) {
      zoom = 13;
    }

    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  /// Get filtered waypoints based on display mode
  List<dynamic> _getFilteredWaypoints() {
    if (widget.day.route == null) return [];
    
    final allWaypoints = widget.day.route!.poiWaypoints;
    
    if (widget.displayMode == MapDisplayMode.selectedOnly) {
      // For trip participants: show all if owner, show selected if participant with selections
      final hasSelections = _dayHasSelections();
      
      if (widget.isOwner || !hasSelections) {
        // Owner or no selections yet: show all waypoints
        return allWaypoints;
      }
      
      // Participant with selections: filter for selected waypoints only
      return allWaypoints.where((wpJson) {
        if (wpJson is! Map<String, dynamic>) return false;
        try {
          final wp = RouteWaypoint.fromJson(wpJson);
          return _isWaypointSelected(wp);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    
    // For 'all' mode, show all waypoints
    return allWaypoints;
  }

  bool _dayHasSelections() {
    final selection = widget.daySelection;
    if (selection == null) return false;
    return selection.selectedAccommodation != null ||
        selection.selectedRestaurants.isNotEmpty ||
        selection.selectedActivities.isNotEmpty;
  }

  bool _isWaypointSelected(RouteWaypoint waypoint) {
    final selection = widget.daySelection;
    if (selection == null) return false;
    
    if (selection.selectedAccommodation?.id == waypoint.id) return true;
    
    for (final restaurant in selection.selectedRestaurants.values) {
      if (restaurant.id == waypoint.id) return true;
    }
    
    for (final activity in selection.selectedActivities) {
      if (activity.id == waypoint.id) return true;
    }
    
    return false;
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

    return GestureDetector(
      onTap: widget.onFullScreen,
      child: Container(
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Map
            fm.FlutterMap(
              mapController: _mapController,
              options: fm.MapOptions(
                initialCenter: initialCenter,
                initialZoom: 12,
                interactionOptions: fm.InteractionOptions(
                  flags: widget.onFullScreen != null 
                      ? fm.InteractiveFlag.none 
                      : fm.InteractiveFlag.all,
                ),
              ),
              children: [
                // Map tiles - using custom Mapbox style
                fm.TileLayer(
                  urlTemplate: defaultRasterTileUrl,
                  userAgentPackageName: 'com.waypoint.app',
                ),
                // Route line
                if (widget.day.route?.geometry != null) _buildRoutePolyline(),
                // Markers (OSM POIs + Custom Waypoints)
                fm.MarkerLayer(markers: _buildMarkers()),
              ],
            ),

            // Edit Route button
            if (widget.showControls && widget.onEditRoute != null)
              Positioned(
                bottom: 12,
                left: 12,
                child: ElevatedButton.icon(
                  onPressed: widget.onEditRoute,
                  icon: const Icon(Icons.edit_location, size: 18),
                  label: const Text('Edit Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            
            // Loading indicator for POIs
            if (_loadingPOIs)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
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
    final day = widget.day;

    // Start marker (A)
    if (day.startLat != null && day.startLng != null) {
      markers.add(
        fm.Marker(
          point: ll.LatLng(day.startLat!, day.startLng!),
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

    // End marker (B)
    if (day.endLat != null && day.endLng != null) {
      markers.add(
        fm.Marker(
          point: ll.LatLng(day.endLat!, day.endLng!),
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
            onTap: () => _showOSMPOIDetails(poi),
            child: _buildOSMPOIMarker(poi),
          ),
        ),
      );
    }

    // Custom waypoint markers (bold, prominent - USER'S PLAN)
    final waypoints = _getFilteredWaypoints();
    for (final wpJson in waypoints) {
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

    return markers;
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

  void _showOSMPOIDetails(POI poi) {
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
