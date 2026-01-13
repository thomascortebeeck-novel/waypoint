import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:go_router/go_router.dart';
import 'package:waypoint/integrations/mapbox_service.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/integrations/google_places_service.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/presentation/widgets/elevation_chart.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/utils/google_link_parser.dart';
import 'package:waypoint/theme.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Full-page route builder screen
class RouteBuilderScreen extends StatefulWidget {
  final ll.LatLng? start;
  final ll.LatLng? end;
  final DayRoute? initial;

  const RouteBuilderScreen({
    super.key,
    this.start,
    this.end,
    this.initial,
  });

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
  final fm.MapController _map = fm.MapController();
  final _svc = MapboxService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _snapToTrail = true;
  bool _busy = false;
  bool _searching = false;
  final _points = <ll.LatLng>[];
  Map<String, dynamic>? _previewGeometry;
  double? _previewDistance;
  int? _previewDuration;
  List<ElevationPoint> _previewElevation = const [];
  double? _previewAscent;
  double? _previewDescent;
  List<PlaceSuggestion> _searchResults = [];

  // POI waypoints
  final List<RouteWaypoint> _poiWaypoints = [];
  bool _waypointsExpanded = true;

  @override
  void initState() {
    super.initState();
    Log.i('route_builder', 'RouteBuilderScreen init');
    try {
      if (widget.start != null) _points.add(widget.start!);
      if (widget.end != null) _points.add(widget.end!);
      if (widget.initial != null) {
        _previewGeometry = widget.initial!.geometry;
        _previewDistance = widget.initial!.distance;
        _previewDuration = widget.initial!.duration;
        if (widget.initial!.waypoints.isNotEmpty && _points.isEmpty) {
          _points.addAll(widget.initial!.waypoints.map((w) => ll.LatLng(w['lat']!, w['lng']!)));
        }
        // Load existing POI waypoints
        if (widget.initial!.poiWaypoints.isNotEmpty) {
          _poiWaypoints.addAll(
            widget.initial!.poiWaypoints.map((w) => RouteWaypoint.fromJson(w)).toList(),
          );
        }
      }
    } catch (e, stack) {
      Log.e('route_builder', 'init failed', e, stack);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _points.isNotEmpty ? _points.first : const ll.LatLng(61.0, 8.5);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alt_route, color: context.colors.primary),
            const SizedBox(width: 8),
            Text('Build Route', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          Text('Snap to trail', style: context.textStyles.bodySmall),
          const SizedBox(width: 8),
          Switch(value: _snapToTrail, onChanged: (v) => setState(() => _snapToTrail = v)),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search location (e.g., Abisko)',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade700),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade700),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : (_searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    _debouncedSearch(v);
                  },
                ),
                // Search results dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (_, i) {
                          final s = _searchResults[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                s.isPoi ? Icons.place : Icons.location_city,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            title: Text(
                              s.text,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                            ),
                            subtitle: Text(
                              s.placeName,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectPlace(s),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                fm.FlutterMap(
                  mapController: _map,
                  options: fm.MapOptions(
                    initialCenter: center,
                    initialZoom: 11,
                    onTap: (tapPos, latLng) async {
                      if (_searchResults.isNotEmpty) {
                        setState(() => _searchResults = []);
                        return;
                      }
                      Log.i('route_builder', 'Map tapped: ${latLng.latitude},${latLng.longitude}');
                      await _showMapTapActionPicker(context, latLng);
                    },
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxPublicToken',
                      userAgentPackageName: 'com.waypoint.app',
                      tileSize: 512,
                      zoomOffset: -1,
                    ),
                    if (_previewGeometry != null)
                      fm.PolylineLayer(
                        polylines: [
                          fm.Polyline(
                            points: _coordsToLatLng(_previewGeometry!['coordinates']),
                            color: const Color(0xFF4CAF50),
                            strokeWidth: 5,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                          )
                        ],
                      ),
                    if (_points.isNotEmpty)
                      fm.MarkerLayer(
                        markers: [
                          for (int i = 0; i < _points.length; i++)
                            fm.Marker(
                              point: _points[i],
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? const Color(0xFF4CAF50)
                                      : (i == _points.length - 1 ? const Color(0xFFF44336) : const Color(0xFFFF9800)),
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
                                child: Center(
                                  child: Icon(
                                    i == 0
                                        ? Icons.play_arrow
                                        : (i == _points.length - 1 ? Icons.flag : Icons.circle),
                                    color: Colors.white,
                                    size: i == _points.length - 1 || i == 0 ? 20 : 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    // POI waypoint markers
                    if (_poiWaypoints.isNotEmpty)
                      fm.MarkerLayer(
                        markers: _poiWaypoints
                            .map((wp) => fm.Marker(
                                  point: wp.position,
                                  width: 48,
                                  height: 48,
                                  child: GestureDetector(
                                    onTap: () => _editWaypoint(wp),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: getWaypointColor(wp.type),
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
                                      child: Center(
                                        child: Icon(
                                          getWaypointIcon(wp.type),
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),

                // Zoom controls
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      _controlButton(icon: Icons.add, onTap: () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
                      const SizedBox(height: 8),
                      _controlButton(icon: Icons.remove, onTap: () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
                    ],
                  ),
                ),

                // Undo/Clear buttons
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      if (_points.isNotEmpty) ...[
                        _controlButton(
                          icon: Icons.undo,
                          label: 'Undo',
                          onTap: () async {
                            setState(() => _points.removeLast());
                            await _updatePreview();
                          },
                        ),
                        const SizedBox(height: 8),
                        _controlButton(
                          icon: Icons.clear_all,
                          label: 'Clear',
                          onTap: () {
                            setState(() {
                              _points.clear();
                              _previewGeometry = null;
                              _previewDistance = null;
                              _previewDuration = null;
                              _previewElevation = [];
                              _previewAscent = null;
                              _previewDescent = null;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Instructions overlay (when no points)
                if (_points.isEmpty && _searchResults.isEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.touch_app,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Tap on the map to add route points or waypoints',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Waypoints list section
          _buildWaypointsSection(),

          // Stats and buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_previewDistance != null) ...[
                  Row(
                    children: [
                      Icon(Icons.straighten, size: 18, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${(_previewDistance! / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.schedule, size: 18, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_previewDuration ?? 0),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_previewElevation.isNotEmpty) ...[
                  SizedBox(height: 120, child: ElevationChart(data: _previewElevation)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_previewAscent != null) ...[
                        Icon(Icons.trending_up, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '+${_previewAscent!.toStringAsFixed(0)} m',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (_previewDescent != null) ...[
                        Icon(Icons.trending_down, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '-${_previewDescent!.toStringAsFixed(0)} m',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || _points.length < 2 ? null : _updatePreview,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.visibility),
                        label: const Text('Preview'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy || _points.length < 2 ? null : _buildAndSave,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Build & Save'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({required IconData icon, String? label, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(label != null ? 12 : 14),
          child: label != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: Colors.grey.shade800),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  ],
                )
              : Icon(icon, size: 22, color: Colors.grey.shade800),
        ),
      ),
    );
  }

  void _debouncedSearch(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    try {
      Log.i('route_builder', '🔍 Starting search for: "$query"');
      final center = _map.camera.center;
      final results = await _svc.searchPlaces(
        query,
        proximityLat: center.latitude,
        proximityLng: center.longitude,
      );

      Log.i('route_builder', '✅ Search returned ${results.length} results');

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e, stack) {
      Log.e('route_builder', '❌ Search failed', e, stack);
      if (mounted) {
        setState(() {
          _searching = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _selectPlace(PlaceSuggestion place) {
    Log.i('route_builder', 'Place selected: ${place.text} at ${place.latitude}, ${place.longitude}');
    final latLng = ll.LatLng(place.latitude, place.longitude);
    _map.move(latLng, 14);
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _updatePreview() async {
    Log.i('route_builder', '_updatePreview called: ${_points.length} points');
    if (_points.length < 2) {
      setState(() {
        _previewGeometry = null;
        _previewDistance = null;
        _previewDuration = null;
        _previewElevation = [];
        _previewAscent = null;
        _previewDescent = null;
      });
      return;
    }

    setState(() => _busy = true);
    try {
      Map<String, dynamic>? match;
      try {
        match = await _svc.matchRoute(points: _points, snapToTrail: _snapToTrail);
      } catch (e) {
        Log.w('route_builder', 'Cloud Function failed, using direct API');
      }

      if (match == null && _snapToTrail) {
        match = await _directionsApiFallback(_points);
      }

      if (match == null) {
        match = {
          'geometry': {'type': 'LineString', 'coordinates': _points.map((p) => [p.longitude, p.latitude]).toList()},
          'distance': _calculateStraightDistance(_points),
          'duration': (_calculateStraightDistance(_points) / 1.2).toInt(),
        };
      }

      if (mounted && match != null) {
        setState(() {
          _previewGeometry = Map<String, dynamic>.from(match!['geometry'] as Map);
          _previewDistance = (match['distance'] as num?)?.toDouble();
          _previewDuration = (match['duration'] as num?)?.toInt();
        });

        try {
          final coords = (_previewGeometry!['coordinates'] as List)
              .map((e) => (e as List).map((n) => (n as num).toDouble()).toList())
              .cast<List<double>>()
              .toList();
          final elev = await _svc.elevationProfile(
            coordinates: coords,
            sampleEveryMeters: 100,
          );
          if (mounted && elev != null) {
            final points = (elev['elevations'] as List?)
                    ?.map((e) => ElevationPoint(
                          (e['distance'] as num).toDouble(),
                          (e['elevation'] as num).toDouble(),
                        ))
                    .toList() ??
                const <ElevationPoint>[];
            setState(() {
              _previewElevation = points;
              _previewAscent = (elev['ascent'] as num?)?.toDouble();
              _previewDescent = (elev['descent'] as num?)?.toDouble();
            });
          }
        } catch (e) {
          Log.w('route_builder', 'Elevation skipped: $e');
        }
      }
    } catch (e, stack) {
      Log.e('route_builder', 'Preview failed', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildAndSave() async {
    if (_previewGeometry == null) {
      await _updatePreview();
      if (_previewGeometry == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please preview the route first')),
          );
        }
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final route = DayRoute(
        geometry: _previewGeometry!,
        distance: _previewDistance ?? 0,
        duration: _previewDuration ?? 0,
        routePoints: _points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        elevationProfile: _previewElevation.map((p) => [p.distance, p.elevation]).toList(),
        ascent: _previewAscent,
        descent: _previewDescent,
        poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList(),
      );

      if (!mounted) return;
      context.pop(route);
    } catch (e, stack) {
      Log.e('route_builder', 'Build failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to build route: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _directionsApiFallback(List<ll.LatLng> waypoints) async {
    try {
      final coords = waypoints.map((w) => '${w.longitude},${w.latitude}').join(';');
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/$coords'
        '?geometries=geojson&overview=full&access_token=$mapboxPublicToken',
      );

      final res = await http.get(url);
      if (res.statusCode != 200) return null;

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final route = (data['routes'] as List?)?.first as Map<String, dynamic>?;
      if (route == null) return null;

      return {
        'geometry': route['geometry'],
        'distance': route['distance'],
        'duration': route['duration'],
      };
    } catch (e) {
      Log.e('route_builder', 'Direct API failed', e);
      return null;
    }
  }

  double _calculateStraightDistance(List<ll.LatLng> points) {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _haversineMeters(points[i - 1], points[i]);
    }
    return total;
  }

  double _haversineMeters(ll.LatLng a, ll.LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final a2 = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    return 2 * R * asin(sqrt(a2));
  }

  List<ll.LatLng> _coordsToLatLng(dynamic coordinates) {
    final list = (coordinates as List).map((e) => (e as List).map((n) => (n as num).toDouble()).toList()).toList();
    return list.map((c) => ll.LatLng(c[1], c[0])).toList();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<void> _showMapTapActionPicker(BuildContext context, ll.LatLng latLng) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What to add?',
                style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _ActionTile(
                icon: Icons.navigation,
                color: const Color(0xFF4CAF50),
                label: 'Route Point',
                onTap: () => Navigator.of(context).pop('route'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.restaurant,
                color: const Color(0xFFFF9800),
                label: 'Restaurant',
                onTap: () => Navigator.of(context).pop('restaurant'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.hotel,
                color: const Color(0xFF2196F3),
                label: 'Accommodation',
                onTap: () => Navigator.of(context).pop('accommodation'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.local_activity,
                color: const Color(0xFF9C27B0),
                label: 'Activity',
                onTap: () => Navigator.of(context).pop('activity'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.visibility,
                color: const Color(0xFFFFC107),
                label: 'Viewing Point',
                onTap: () => Navigator.of(context).pop('viewingPoint'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'route') {
      setState(() => _points.add(latLng));
      await _updatePreview();
    } else {
      final type = WaypointType.values.firstWhere((t) => t.name == action);
      await _addWaypointAtLocation(type, latLng);
    }
  }

  Future<void> _addWaypointAtLocation(WaypointType type, ll.LatLng position) async {
    final result = await showDialog<RouteWaypoint>(
      context: context,
      builder: (context) => _AddWaypointDialog(
        preselectedType: type,
        proximityBias: position,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _poiWaypoints.add(result);
      });
    }
  }

  Future<void> _editWaypoint(RouteWaypoint waypoint) async {
    final result = await showDialog<RouteWaypoint>(
      context: context,
      builder: (context) => _WaypointEditorDialog(
        existingWaypoint: waypoint,
        type: waypoint.type,
        position: waypoint.position,
      ),
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _poiWaypoints.removeWhere((w) => w.id == waypoint.id);
      });
    } else {
      setState(() {
        final index = _poiWaypoints.indexWhere((w) => w.id == waypoint.id);
        if (index >= 0) {
          _poiWaypoints[index] = result;
        }
      });
    }
  }

  Widget _buildWaypointsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _waypointsExpanded = !_waypointsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _waypointsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waypoints (${_poiWaypoints.length})',
                    style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: context.colors.primary,
                    onPressed: () => _showAddWaypointDialog(),
                    tooltip: 'Add Waypoint',
                  ),
                ],
              ),
            ),
          ),
          if (_waypointsExpanded && _poiWaypoints.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No waypoints added yet. Tap on the map or use the + button.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          if (_waypointsExpanded && _poiWaypoints.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _poiWaypoints.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _poiWaypoints.removeAt(oldIndex);
                    _poiWaypoints.insert(newIndex, item);
                    for (int i = 0; i < _poiWaypoints.length; i++) {
                      _poiWaypoints[i].order = i;
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final wp = _poiWaypoints[index];
                  return Card(
                    key: ValueKey(wp.id),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle, color: Colors.grey),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: getWaypointColor(wp.type),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(getWaypointIcon(wp.type), color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wp.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (wp.rating != null)
                                  Row(
                                    children: [
                                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                                      const SizedBox(width: 2),
                                      Text(
                                        wp.rating!.toStringAsFixed(1),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                if (wp.type == WaypointType.accommodation && wp.accommodationType != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: wp.accommodationType == AccommodationType.hotel
                                          ? Colors.blue.shade50
                                          : Colors.pink.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      wp.accommodationType == AccommodationType.hotel ? 'Hotel' : 'Airbnb',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: wp.accommodationType == AccommodationType.hotel
                                            ? Colors.blue.shade900
                                            : Colors.pink.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _editWaypoint(wp),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddWaypointDialog() async {
    ll.LatLng? proximityBias;
    if (_points.isNotEmpty) {
      final midIndex = _points.length ~/ 2;
      proximityBias = _points[midIndex];
    }
    
    final result = await showDialog<RouteWaypoint>(
      context: context,
      builder: (context) => _AddWaypointDialog(
        proximityBias: proximityBias,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _poiWaypoints.add(result);
        _map.move(result.position, _map.camera.zoom);
      });
    }
  }
}

/// Action tile for map tap picker
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
}

/// Add waypoint dialog with Google Places search
class _AddWaypointDialog extends StatefulWidget {
  final WaypointType? preselectedType;
  final ll.LatLng? proximityBias;
  
  const _AddWaypointDialog({
    this.preselectedType,
    this.proximityBias,
  });

  @override
  State<_AddWaypointDialog> createState() => _AddWaypointDialogState();
}

class _AddWaypointDialogState extends State<_AddWaypointDialog> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _airbnbAddressController = TextEditingController();
  final _placesService = GooglePlacesService();
  late WaypointType _selectedType;
  AccommodationType? _accommodationType;
  List<PlacePrediction> _searchResults = [];
  PlaceDetails? _selectedPlace;
  bool _searching = false;
  bool _geocoding = false;
  ll.LatLng? _airbnbLocation;
  bool _airbnbAddressConfirmed = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType ?? WaypointType.restaurant;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _airbnbAddressController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Check if user pasted a Google Maps link
    if (GoogleLinkParser.isGoogleMapsUrl(query)) {
      // ✅ ADD DEBOUNCE: Wait 300ms before processing
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _searchController.text.trim() == query) {
          _handleGoogleLink(query);
        }
      });
      return;
    }
    
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  /// Handle Google Maps link paste
  Future<void> _handleGoogleLink(String url) async {
    // Show immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Processing Google Maps link...'),
            ],
          ),
          duration: Duration(seconds: 30), // Long duration
        ),
      );
    }
    
    setState(() => _searching = true);
    
    try {
      // Try to extract place ID from URL
      String? placeId = GoogleLinkParser.extractPlaceId(url);
      
      // If not found, try expanding short URL
      if (placeId == null && (url.contains('goo.gl') || url.contains('share.google'))) {
        Log.i('waypoint_dialog', 'Expanding short URL...');
        placeId = await GoogleLinkParser.expandShortUrl(url);
      }
      
      if (placeId != null) {
        Log.i('waypoint_dialog', 'Place ID extracted: $placeId');
        
        // Fetch place details directly
        final details = await _placesService.getPlaceDetails(placeId);
        
        if (details != null && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
          setState(() {
            _selectedPlace = details;
            _nameController.text = details.name;
            _descController.text = details.address ?? '';
            _searchController.text = details.name;
            _searching = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Place loaded from Google link!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      
      // Failed to extract place - CRITICAL FIX: Clear the search field!
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
        setState(() {
          _searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
          _searching = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract place from this link. Try searching instead.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Log.e('waypoint_dialog', 'Failed to process Google link', e);
      
      // CRITICAL FIX: Clear the search field on any error!
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // Clear loading message
        setState(() {
          _searchController.clear(); // ✅ CLEAR TO STOP INFINITE LOOP
          _searching = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing link: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    
    try {
      List<String>? typeFilters;
      switch (_selectedType) {
        case WaypointType.restaurant:
          typeFilters = ['restaurant', 'cafe', 'bar'];
          break;
        case WaypointType.accommodation:
          typeFilters = ['lodging', 'hotel'];
          break;
        case WaypointType.activity:
          typeFilters = ['tourist_attraction', 'point_of_interest'];
          break;
        case WaypointType.viewingPoint:
          typeFilters = ['tourist_attraction', 'natural_feature'];
          break;
      }
      
      final results = await _placesService.searchPlaces(
        query: query,
        proximity: widget.proximityBias,
        types: typeFilters,
      );
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e) {
      Log.e('waypoint_dialog', 'Search failed', e);
      if (mounted) {
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    final details = await _placesService.getPlaceDetails(prediction.placeId);
    
    if (details != null && mounted) {
      setState(() {
        _selectedPlace = details;
        _nameController.text = details.name;
        _descController.text = details.address ?? '';
        _searchController.text = details.name;
        _searchResults = [];
      });
    }
  }

  Future<void> _geocodeAirbnbAddress() async {
    final address = _airbnbAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an address first')),
      );
      return;
    }
    
    setState(() => _geocoding = true);
    
    final location = await _placesService.geocodeAddress(address);
    
    setState(() => _geocoding = false);
    
    if (location != null) {
      setState(() {
        _airbnbLocation = location;
        _airbnbAddressConfirmed = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location found! ✓'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find location. Please check the address.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt),
                    const SizedBox(width: 8),
                    const Text('Add Waypoint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for a place or paste Google Maps link',
                          helperText: 'Tip: You can paste Google Maps share links directly',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_searchResults.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final result = _searchResults[i];
                              return ListTile(
                                dense: true,
                                leading: Icon(getWaypointIcon(_selectedType), size: 20),
                                title: Text(result.text),
                                onTap: () => _selectPlace(result),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ✅ "Powered by Google" Attribution
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://developers.google.com/static/maps/images/powered-by-google-on-white.png',
                              height: 16,
                              errorBuilder: (_, __, ___) => Text(
                                'Powered by Google',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_selectedPlace != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedPlace!.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    if (_selectedPlace!.rating != null)
                                      Text(
                                        '⭐ ${_selectedPlace!.rating!.toStringAsFixed(1)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() {
                                  _selectedPlace = null;
                                  _searchController.clear();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // ✅ "Powered by Google" Attribution
                        Text(
                          'Powered by Google Places',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: WaypointType.values
                            .map((type) => ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(getWaypointIcon(type), size: 16),
                                      const SizedBox(width: 4),
                                      Text(getWaypointLabel(type)),
                                    ],
                                  ),
                                  selected: _selectedType == type,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedType = type;
                                        _searchResults = [];
                                        if (_searchController.text.isNotEmpty) {
                                          _performSearch(_searchController.text);
                                        }
                                      });
                                    }
                                  },
                                  selectedColor: getWaypointColor(type).withValues(alpha: 0.3),
                                ))
                            .toList(),
                      ),
                      if (_selectedType == WaypointType.accommodation) ...[
                        const SizedBox(height: 16),
                        const Text('Accommodation Type *', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hotel, size: 16),
                                    SizedBox(width: 4),
                                    Text('Hotel'),
                                  ],
                                ),
                                selected: _accommodationType == AccommodationType.hotel,
                                onSelected: (selected) {
                                  if (selected) setState(() => _accommodationType = AccommodationType.hotel);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.home, size: 16),
                                    SizedBox(width: 4),
                                    Text('Airbnb'),
                                  ],
                                ),
                                selected: _accommodationType == AccommodationType.airbnb,
                                onSelected: (selected) {
                                  if (selected) setState(() => _accommodationType = AccommodationType.airbnb);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (_accommodationType == AccommodationType.airbnb) ...[
                          const SizedBox(height: 16),
                          const Text('Airbnb Property', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _airbnbAddressController,
                            decoration: InputDecoration(
                              labelText: 'Address or Location',
                              hintText: 'e.g., 123 Main St, Oslo, Norway',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              helperText: 'We\'ll use this to place the marker on the map',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _geocoding ? null : _geocodeAirbnbAddress,
                            icon: _geocoding 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 18),
                            label: Text(_geocoding ? 'Finding...' : 'Find Location'),
                          ),
                          if (_airbnbAddressConfirmed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Location confirmed',
                                    style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          hintText: 'e.g., Café Aurora',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Add details...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _canSave() ? _save : null,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  bool _canSave() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedType == WaypointType.accommodation && _accommodationType == null) return false;
    if (_accommodationType == AccommodationType.airbnb && !_airbnbAddressConfirmed) return false;
    if (_accommodationType != AccommodationType.airbnb && _selectedPlace == null) return false;
    return true;
  }

  void _save() async {
    if (!_canSave()) return;

    String? photoUrl;
    if (_selectedPlace?.photoReference != null) {
      final waypointId = const Uuid().v4();
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Caching photo...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Use cached photo method
      photoUrl = await _placesService.getCachedPhotoUrl(
        _selectedPlace!.photoReference!,
        waypointId,
      );
    }

    ll.LatLng position;
    if (_accommodationType == AccommodationType.airbnb && _airbnbLocation != null) {
      position = _airbnbLocation!;
    } else if (_selectedPlace != null) {
      position = _selectedPlace!.location;
    } else {
      return;
    }

    final waypoint = RouteWaypoint(
      type: _selectedType,
      position: position,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      order: 0,
      googlePlaceId: _selectedPlace?.placeId,
      address: _accommodationType == AccommodationType.airbnb 
          ? _airbnbAddressController.text.trim()
          : _selectedPlace?.address,
      rating: _selectedPlace?.rating,
      website: _selectedPlace?.website,
      phoneNumber: _selectedPlace?.phoneNumber,
      photoUrl: photoUrl,
      accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
    );

    Navigator.of(context).pop(waypoint);
  }
}

/// Enhanced waypoint editor dialog
class _WaypointEditorDialog extends StatefulWidget {
  final RouteWaypoint? existingWaypoint;
  final WaypointType type;
  final ll.LatLng position;

  const _WaypointEditorDialog({
    this.existingWaypoint,
    required this.type,
    required this.position,
  });

  @override
  State<_WaypointEditorDialog> createState() => _WaypointEditorDialogState();
}

class _WaypointEditorDialogState extends State<_WaypointEditorDialog> {
  late WaypointType _selectedType;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _websiteController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _hotelChainController;
  late final TextEditingController _bookingUrlController;
  late final TextEditingController _airbnbUrlController;
  late final TextEditingController _priceMinController;
  late final TextEditingController _priceMaxController;

  double? _rating;
  List<String> _amenities = [];
  AccommodationType? _accommodationType;
  final List<String> _availableAmenities = [
    'WiFi',
    'Parking',
    'Pool',
    'Gym',
    'Spa',
    'Restaurant',
    'Bar',
    'Room Service',
    'Air Conditioning',
    'Pet Friendly'
  ];

  @override
  void initState() {
    super.initState();
    final wp = widget.existingWaypoint;
    _selectedType = wp?.type ?? widget.type;
    _accommodationType = wp?.accommodationType;
    _nameController = TextEditingController(text: wp?.name ?? '');
    _descriptionController = TextEditingController(text: wp?.description ?? '');
    _photoUrlController = TextEditingController(text: wp?.photoUrl ?? '');
    _websiteController = TextEditingController(text: wp?.website ?? '');
    _phoneController = TextEditingController(text: wp?.phoneNumber ?? '');
    _addressController = TextEditingController(text: wp?.address ?? '');
    _hotelChainController = TextEditingController(text: wp?.hotelChain ?? '');
    _bookingUrlController = TextEditingController(text: wp?.bookingComUrl ?? '');
    _airbnbUrlController = TextEditingController(text: wp?.airbnbPropertyUrl ?? '');
    _priceMinController = TextEditingController(text: wp?.estimatedPriceRange?.min.toString() ?? '');
    _priceMaxController = TextEditingController(text: wp?.estimatedPriceRange?.max.toString() ?? '');
    _rating = wp?.rating;
    _amenities = List.from(wp?.amenities ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _photoUrlController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _hotelChainController.dispose();
    _bookingUrlController.dispose();
    _airbnbUrlController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: getWaypointColor(_selectedType).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(getWaypointIcon(_selectedType), color: getWaypointColor(_selectedType)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.existingWaypoint == null ? 'Add Waypoint' : 'Edit Waypoint',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommonFields(),
                      const SizedBox(height: 16),
                      if (_selectedType != WaypointType.accommodation) _buildPoiFields(),
                      if (_selectedType == WaypointType.accommodation) _buildAccommodationFields(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.existingWaypoint != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(widget.existingWaypoint),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveWaypoint,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildCommonFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<WaypointType>(
            value: _selectedType,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: WaypointType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(getWaypointIcon(type), color: getWaypointColor(type), size: 20),
                          const SizedBox(width: 8),
                          Text(getWaypointLabel(type)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedType = value);
            },
          ),
          if (_selectedType == WaypointType.accommodation) ...[
            const SizedBox(height: 16),
            const Text('Accommodation Type *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hotel, size: 16),
                        SizedBox(width: 4),
                        Text('Hotel'),
                      ],
                    ),
                    selected: _accommodationType == AccommodationType.hotel,
                    onSelected: (selected) {
                      if (selected) setState(() => _accommodationType = AccommodationType.hotel);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home, size: 16),
                        SizedBox(width: 4),
                        Text('Airbnb'),
                      ],
                    ),
                    selected: _accommodationType == AccommodationType.airbnb,
                    onSelected: (selected) {
                      if (selected) setState(() => _accommodationType = AccommodationType.airbnb);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('Name *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Mountain View Café',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add details...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Photo URL', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _photoUrlController,
            decoration: InputDecoration(
              hintText: 'https://example.com/image.jpg',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      );

  Widget _buildPoiFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          const Text('POI Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            value: _rating,
            decoration: InputDecoration(
              hintText: 'Select rating',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                  i < r.floor() ? Icons.star : (i < r ? Icons.star_half : Icons.star_border),
                                  color: Colors.amber,
                                  size: 20,
                                )),
                      ),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          const Text('Address', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Enter address',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Website', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _websiteController,
            decoration: InputDecoration(
              hintText: 'https://example.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              hintText: '+1 234 567 8900',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      );

  Widget _buildAccommodationFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          const Text('Accommodation Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_accommodationType == AccommodationType.hotel) ...[
            const Text('Hotel Chain', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _hotelChainController,
              decoration: InputDecoration(
                hintText: 'e.g., Marriott, Hilton',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text('Address', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Enter address',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<double>(
            value: _rating,
            decoration: InputDecoration(
              hintText: 'Select rating',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                  i < r.floor() ? Icons.star : (i < r ? Icons.star_half : Icons.star_border),
                                  color: Colors.amber,
                                  size: 20,
                                )),
                      ),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAmenities.map((amenity) {
              final isSelected = _amenities.contains(amenity);
              return FilterChip(
                label: Text(amenity),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _amenities.add(amenity);
                    } else {
                      _amenities.remove(amenity);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Estimated Price Range (per night)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceMinController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Min €',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _priceMaxController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Max €',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_accommodationType == AccommodationType.hotel) ...[
            const Text('Booking.com URL', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _bookingUrlController,
              decoration: InputDecoration(
                hintText: 'https://booking.com/...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
          if (_accommodationType == AccommodationType.airbnb) ...[
            const Text('Airbnb Property URL *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _airbnbUrlController,
              decoration: InputDecoration(
                hintText: 'https://airbnb.com/rooms/...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ],
      );

  void _saveWaypoint() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    if (_selectedType == WaypointType.accommodation && _accommodationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select accommodation type')),
      );
      return;
    }

    if (_accommodationType == AccommodationType.airbnb && _airbnbUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Airbnb URL')),
      );
      return;
    }

    // Basic URL validation
    final bookingUrl = _bookingUrlController.text.trim();
    final airbnbUrl = _airbnbUrlController.text.trim();
    final websiteUrl = _websiteController.text.trim();

    if (bookingUrl.isNotEmpty && !bookingUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking URL must start with http:// or https://')),
      );
      return;
    }

    if (airbnbUrl.isNotEmpty && !airbnbUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Airbnb URL must start with http:// or https://')),
      );
      return;
    }

    if (websiteUrl.isNotEmpty && !websiteUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Website URL must start with http:// or https://')),
      );
      return;
    }

    PriceRange? priceRange;
    final minPrice = double.tryParse(_priceMinController.text.trim());
    final maxPrice = double.tryParse(_priceMaxController.text.trim());
    if (minPrice != null && maxPrice != null && minPrice > 0 && maxPrice > 0) {
      priceRange = PriceRange(min: minPrice, max: maxPrice);
    }

    final waypoint = RouteWaypoint(
      id: widget.existingWaypoint?.id,
      type: _selectedType,
      position: widget.position,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      order: widget.existingWaypoint?.order ?? 0,
      photoUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
      rating: _rating,
      website: websiteUrl.isEmpty ? null : websiteUrl,
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      accommodationType: _selectedType == WaypointType.accommodation ? _accommodationType : null,
      hotelChain: _hotelChainController.text.trim().isEmpty ? null : _hotelChainController.text.trim(),
      amenities: _amenities.isEmpty ? null : _amenities,
      estimatedPriceRange: priceRange,
      bookingComUrl: bookingUrl.isEmpty ? null : bookingUrl,
      airbnbPropertyUrl: airbnbUrl.isEmpty ? null : airbnbUrl,
    );
    Navigator.of(context).pop(waypoint);
  }
}
