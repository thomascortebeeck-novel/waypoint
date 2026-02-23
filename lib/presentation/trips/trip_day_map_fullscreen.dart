import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/features/map/adaptive_map_widget.dart';
import 'package:waypoint/features/map/map_configuration.dart';
import 'package:waypoint/features/map/waypoint_map_controller.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/presentation/widgets/elevation_chart.dart';
import 'package:waypoint/theme.dart';
import 'package:waypoint/components/map/waypoint_map_legend.dart';

/// Full-screen map view for a trip day (AllTrails-style)
/// Uses AdaptiveMapWidget with Mapbox rendering for beautiful 3D terrain
class TripDayMapFullscreen extends StatefulWidget {
  final DayItinerary day;
  final int dayNumber;

  const TripDayMapFullscreen({
    super.key,
    required this.day,
    required this.dayNumber,
  });

  @override
  State<TripDayMapFullscreen> createState() => _TripDayMapFullscreenState();
}

class _TripDayMapFullscreenState extends State<TripDayMapFullscreen> {
  WaypointMapController? _mapController;
  bool _showElevation = false;
  bool _mapReady = false;

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
      }
    });
  }

  /// Add route and markers using controller API
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
      debugPrint('Added route with ${routePoints.length} points');
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
    if (widget.day.route != null && widget.day.route!.poiWaypoints.isNotEmpty) {
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
        } catch (e) {
          debugPrint('Skipping waypoint: $e');
        }
      }
    }
  }

  Future<void> _fitBounds() async {
    if (!_mapReady || !mounted || _mapController == null) return;
    
    final day = widget.day;
    final bounds = <ll.LatLng>[];

    // Add route geometry points
    final routePoints = _parseRouteCoordinates();
    if (routePoints.isNotEmpty) {
      bounds.addAll(routePoints);
    }

    // Add start/end points
    if (day.startLat != null && day.startLng != null) {
      bounds.add(ll.LatLng(day.startLat!, day.startLng!));
    }
    if (day.endLat != null && day.endLng != null) {
      bounds.add(ll.LatLng(day.endLat!, day.endLng!));
    }

    // Add waypoint positions
    if (day.route != null && day.route!.poiWaypoints.isNotEmpty) {
      for (final wpJson in day.route!.poiWaypoints) {
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
    // Calculate initial center
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
          // Top app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.pop(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Day ${widget.dayNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _buildTopButton(
                      icon: Icons.layers_outlined,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right side controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
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
              ],
            ),
          ),

          // Bottom sheet with elevation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -5) {
                  setState(() => _showElevation = true);
                } else if (details.delta.dy > 5) {
                  setState(() => _showElevation = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: _showElevation ? MediaQuery.of(context).size.height * 0.5 : 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.day.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatChip(
                                icon: Icons.straighten,
                                label: '${widget.day.distanceKm.toStringAsFixed(1)} km',
                              ),
                              const SizedBox(width: 12),
                              _buildStatChip(
                                icon: Icons.schedule,
                                label: _formatDuration(widget.day.estimatedTimeMinutes),
                              ),
                              if (widget.day.route?.ascent != null) ...[
                                const SizedBox(width: 12),
                                _buildStatChip(
                                  icon: Icons.trending_up,
                                  label: '${widget.day.route!.ascent!.toStringAsFixed(0)} m',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_showElevation && widget.day.route?.elevationProfile != null)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Elevation Profile',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 180,
                                  child: ElevationChart(
                                    data: widget.day.route!.elevationProfile!,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!_showElevation)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.download_outlined,
                                label: 'Download',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Download feature coming soon')),
                                  );
                                },
                                isPrimary: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.navigation,
                                label: 'Start',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Navigation feature coming soon')),
                                  );
                                },
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF4CAF50) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : Colors.black87,
        elevation: 0,
        side: isPrimary ? null : BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }
}
