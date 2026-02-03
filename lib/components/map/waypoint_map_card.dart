import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
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
  WaypointMapController? _mapController;
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
    if (_loadingPOIs || !_mapReady || _mapController == null) return;
    
    setState(() => _loadingPOIs = true);
    Log.i('map', '🔍 Starting to load OSM POIs...');
    
    try {
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
      
      // Load main outdoor POI types
      final pois = await POIService.fetchPOIs(
        southWest: ll.LatLng(center.latitude - latOffset, center.longitude - lngOffset),
        northEast: ll.LatLng(center.latitude + latOffset, center.longitude + lngOffset),
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

  Future<void> _fitBounds() async {
    if (!_mapReady || !mounted || _mapController == null) return;
    
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
      await _mapController!.animateCamera(center, zoom);
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

    // Build annotations for markers
    final annotations = _buildAnnotations();
    
    // Build polylines for route
    final routePoints = _parseRouteCoordinates();
    final polylines = routePoints.isNotEmpty
        ? [
            MapPolyline(
              id: 'route_${widget.day.title}',
              points: routePoints,
              color: const Color(0xFF4CAF50),
              width: 4.0,
              borderColor: Colors.white,
              borderWidth: 2.0,
            )
          ]
        : <MapPolyline>[];

    // Map configuration for preview cards
    final mapConfig = MapConfiguration.mainMap(
      styleUri: mapboxStyleUri,
      rasterTileUrl: defaultRasterTileUrl,
      enable3DTerrain: false, // Flat for preview cards
      initialZoom: 12.0,
    );

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
            // Map using AdaptiveMapWidget (Mapbox WebGL on web, Native on mobile)
            AdaptiveMapWidget(
              initialCenter: initialCenter,
              configuration: mapConfig,
              annotations: annotations,
              polylines: polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                _onMapReady();
              },
              onCameraChanged: widget.fetchOSMPOIs ? (camera) {
                // Debounce POI loading on camera change
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _mapReady) {
                    _loadPOIs();
                  }
                });
              } : null,
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

  List<MapAnnotation> _buildAnnotations() {
    final annotations = <MapAnnotation>[];
    final day = widget.day;

    // Start marker (A) - using custom annotation
    if (day.startLat != null && day.startLng != null) {
      annotations.add(
        MapAnnotation(
          id: 'start',
          position: ll.LatLng(day.startLat!, day.startLng!),
          icon: Icons.flag,
          color: const Color(0xFF52B788),
          label: 'A',
          onTap: () {},
        ),
      );
    }

    // End marker (B) - using custom annotation
    if (day.endLat != null && day.endLng != null) {
      annotations.add(
        MapAnnotation(
          id: 'end',
          position: ll.LatLng(day.endLat!, day.endLng!),
          icon: Icons.flag,
          color: const Color(0xFFD62828),
          label: 'B',
          onTap: () {},
        ),
      );
    }

    // OSM POI markers (subtle, background context)
    for (final poi in _osmPOIs) {
      annotations.add(
        MapAnnotation.fromPOI(
          poi,
          onTap: () => _showOSMPOIDetails(poi),
        ),
      );
    }

    // Custom waypoint markers (match Mapbox native style)
    final waypoints = _getFilteredWaypoints();
    for (final wpJson in waypoints) {
      try {
        if (wpJson is Map<String, dynamic> && 
            wpJson['position'] != null &&
            wpJson['position']['lat'] != null && 
            wpJson['position']['lng'] != null) {
          final wp = RouteWaypoint.fromJson(wpJson);
          annotations.add(
            MapAnnotation.fromWaypoint(
              wp,
              onTap: () => _showWaypointDetails(wp),
            ),
          );
        }
      } catch (_) {}
    }

    return annotations;
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
