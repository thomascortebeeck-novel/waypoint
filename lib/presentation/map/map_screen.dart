import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:waypoint/integrations/offline_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:waypoint/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/integrations/mapbox_service.dart';
import 'package:waypoint/integrations/offline_manager.dart';
import 'package:waypoint/presentation/map/offline_manager_sheet.dart';
import 'package:waypoint/models/poi_model.dart';
import 'package:waypoint/services/poi_service.dart';
import 'dart:math' as math;
import 'package:waypoint/utils/logger.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Mock current location (Norway for Arctic Trail)
  final LatLng _center = const LatLng(61.0, 8.5);
  bool _isOffline = false;
  bool _downloading = false;
  double _progress = 0.0;
  final MapController _controller = MapController();
  
  // POI state
  List<POI> _pois = [];
  Set<POIType> _enabledPOITypes = {
    POIType.campsite,
    POIType.hut,
    POIType.viewpoint,
  };
  bool _loadingPOIs = false;
  POI? _selectedPOI;
  Timer? _poiLoadTimer;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  List<PlaceSuggestion> _searchResults = [];
  LatLng? _searchMarker;

  @override
  void initState() {
    super.initState();
    Log.i('map', 'MapScreen init, center=${_center.latitude},${_center.longitude}, web=$kIsWeb');
    
    // Load POIs when map moves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.mapEventStream.listen((event) {
        if (event is MapEventMoveEnd) {
          _loadPOIsForArea();
        }
      });
      
      // Initial POI load
      _loadPOIsForArea();
    });
  }
  
  @override
  void dispose() {
    _poiLoadTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPOIsForArea() async {
    _poiLoadTimer?.cancel();
    _poiLoadTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_enabledPOITypes.isEmpty) return;
      
      setState(() => _loadingPOIs = true);
      
      try {
        final bounds = _controller.camera.visibleBounds;
        final pois = await POIService.fetchPOIs(
          southWest: bounds.southWest!,
          northEast: bounds.northEast!,
          poiTypes: _enabledPOITypes.toList(),
          maxResults: 500,
        );
        
        if (mounted) {
          setState(() {
            _pois = pois;
            _loadingPOIs = false;
          });
          
          if (pois.isEmpty && _enabledPOITypes.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('No POIs found in this area'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.grey[700],
              ),
            );
          }
        }
      } catch (e) {
        Log.e('poi', 'Failed to load POIs', e);
        if (mounted) {
          setState(() => _loadingPOIs = false);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to load POIs - try zooming in or check connection'),
              backgroundColor: context.colors.error,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _loadPOIsForArea(),
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleSearch(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    
    try {
      final results = await MapboxService().searchPlaces(
        query,
        proximityLat: _controller.camera.center.latitude,
        proximityLng: _controller.camera.center.longitude,
        countries: 'se,no,fi,dk,is', // Scandinavia
      );
      
      setState(() => _searchResults = results);
    } catch (e) {
      Log.e('search', 'Failed to search', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.i('map', 'Building map with token=${hasValidMapboxToken}, tileProvider=${kIsWeb ? 'Network' : 'OfflineOrNetwork'}');
    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          FlutterMap(
            mapController: _controller,
            options: MapOptions(initialCenter: _center, initialZoom: 11.0),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/thomascortebeeck93/cmkv0yv7a006401s9akepciwf/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
                userAgentPackageName: 'com.waypoint.app',
                tileProvider: kIsWeb ? NetworkTileProvider() : tileProviderOrNetwork(),
              ),
              PolylineLayer(polylines: [
                Polyline(points: [const LatLng(60.9, 8.4), const LatLng(60.95, 8.45), const LatLng(61.0, 8.5), const LatLng(61.05, 8.55), const LatLng(61.1, 8.6)], strokeWidth: 4.0, color: context.colors.primary)
              ]),
              MarkerLayer(markers: [
                // User location puck
                Marker(point: _center, width: 40, height: 40, child: _puck(context)),
                
                // Search result marker
                if (_searchMarker != null)
                  Marker(
                    point: _searchMarker!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.place, color: Colors.red, size: 40),
                  ),
                
                // POI markers
                ..._pois.where((poi) => _enabledPOITypes.contains(poi.type)).map(
                  (poi) => Marker(
                    point: poi.coordinates,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPOI = poi),
                      child: Container(
                        decoration: BoxDecoration(
                          color: poi.type.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Icon(
                          poi.type.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ])
            ],
          ),

          // 2. Top Bar (Back + Search + Stats + Offline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  
                  // Search button
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () => setState(() => _showSearch = !_showSearch),
                    ),
                  ),
                  
                  // Quick Stats
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "4.2 km/h",
                          style: context.textStyles.labelMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.landscape, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "1,240m",
                          style: context.textStyles.labelMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Offline Toggle
                  GestureDetector(
                    onTap: _downloading ? null : () async {
                      setState(() {
                        _isOffline = true;
                        _downloading = true;
                        _progress = 0;
                      });
                      try {
                        final bounds = _approxBounds(_controller.camera.center, _controller.camera.zoom);
                        Log.i('offline', 'Start download bounds: SW(${bounds.$1.latitude},${bounds.$1.longitude}) NE(${bounds.$2.latitude},${bounds.$2.longitude})');
                        await OfflineTilesManager().downloadLatLngBounds(
                          southWest: bounds.$1,
                          northEast: bounds.$2,
                          minZoom: 8,
                          maxZoom: 14,
                          onProgress: (p) => setState(() => _progress = p),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline pack ready for this area')));
                        }
                      } catch (e) {
                        Log.e('offline', 'download failed', e);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline download failed')));
                        }
                      } finally {
                        if (mounted) setState(() => _downloading = false);
                      }
                    },
                    onLongPress: () {
                      showModalBottomSheet(context: context, builder: (_) => const OfflineManagerSheet());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isOffline ? context.colors.secondary : Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOffline ? Icons.cloud_download : Icons.cloud_queue,
                            color: Colors.white,
                            size: 16,
                          ),
                          if (_isOffline) ...[
                            const SizedBox(width: 6),
                            if (_downloading)
                              Text('${(_progress * 100).toStringAsFixed(0)}%', style: context.textStyles.labelSmall?.copyWith(color: Colors.white))
                            else
                              Text('Offline', style: context.textStyles.labelSmall?.copyWith(color: Colors.white)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Search Sheet
          if (_showSearch)
            Positioned(
              top: 130,
              left: 20,
              right: 20,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search locations...',
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults = [];
                                _showSearch = false;
                              });
                            },
                          ),
                        ),
                        onChanged: _handleSearch,
                      ),
                      
                      // Results list
                      if (_searchResults.isNotEmpty) ...[
                        const Divider(height: 1),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.place),
                              title: Text(result.text),
                              subtitle: Text(
                                result.placeName,
                                style: context.textStyles.bodySmall,
                              ),
                              onTap: () {
                                // Fly to location
                                _controller.move(
                                  LatLng(result.latitude, result.longitude),
                                  13.0,
                                );
                                
                                // Add marker
                                setState(() {
                                  _searchMarker = LatLng(result.latitude, result.longitude);
                                  _showSearch = false;
                                  _searchController.clear();
                                  _searchResults = [];
                                });
                                
                                // Load POIs for this area
                                _loadPOIsForArea();
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 4. POI Loading Indicator
          if (_loadingPOIs)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading POIs...',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. POI Filter Panel
          Positioned(
            top: 140,
            right: 20,
            bottom: 200,
            child: Container(
              width: 50,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.lg),
                        topRight: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_pois.where((p) => _enabledPOITypes.contains(p.type)).length}',
                          style: context.textStyles.titleMedium?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'POIs',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: context.colors.primary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: POIType.values
                            .where((type) => type != POIType.other)
                            .map((type) {
                          final enabled = _enabledPOITypes.contains(type);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (enabled) {
                                  _enabledPOITypes.remove(type);
                                } else {
                                  _enabledPOITypes.add(type);
                                }
                              });
                              _loadPOIsForArea();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: enabled 
                                  ? type.color.withValues(alpha: 0.2)
                                  : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                              child: Icon(
                                type.icon,
                                color: enabled ? type.color : Colors.grey,
                                size: 24,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. POI Detail Popup
          if (_selectedPOI != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedPOI!.type.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _selectedPOI!.type.icon,
                            color: _selectedPOI!.type.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPOI!.name,
                                style: context.textStyles.titleMedium,
                              ),
                              Text(
                                _selectedPOI!.type.displayName,
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _selectedPOI = null),
                        ),
                      ],
                    ),
                    
                    if (_selectedPOI!.description != null && _selectedPOI!.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _selectedPOI!.description!,
                        style: context.textStyles.bodySmall,
                      ),
                    ],
                    
                    // Additional details from OSM tags
                    if (_selectedPOI!.elevation != null || _selectedPOI!.capacity != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (_selectedPOI!.elevation != null)
                            Text(
                              '⛰️ ${_selectedPOI!.elevation}m',
                              style: context.textStyles.bodySmall,
                            ),
                          if (_selectedPOI!.capacity != null)
                            Text(
                              '👥 ${_selectedPOI!.capacity}',
                              style: context.textStyles.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 7. Bottom Controls (Emergency + Info)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 // Emergency Button
                 FloatingActionButton(
                   backgroundColor: context.colors.error,
                   onPressed: () {
                     // Trigger SOS logic
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text("Sending Emergency Coords: 61.0, 8.5")),
                     );
                   },
                   child: const Icon(Icons.sos, color: Colors.white),
                 ),

                 // Expandable Sheet Trigger
                 Container(
                   width: 200,
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: context.colors.surface,
                     borderRadius: BorderRadius.circular(AppRadius.lg),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withValues(alpha: 0.1),
                         blurRadius: 10,
                       ),
                     ],
                   ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text("Next Stop", style: context.textStyles.labelSmall),
                       const SizedBox(height: 4),
                       Text("Glacier Viewpoint", style: context.textStyles.titleMedium),
                       const SizedBox(height: 4),
                       Text("2.4 km • 45 min", style: context.textStyles.bodySmall?.copyWith(color: Colors.grey)),
                     ],
                   ),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _puck(BuildContext context) => Container(
        decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: const Icon(Icons.navigation, color: Colors.white, size: 20),
      );

  /// Very rough geographic bounds approximation around the current center based on zoom.
  /// Keeps implementation simple for preview; offline downloader receives SW/NE corners.
  (LatLng, LatLng) _approxBounds(LatLng center, double zoom) {
    final viewportKm = (200 / math.pow(2, zoom - 6)).clamp(10, 80);
    final latDegrees = viewportKm / 111.0;
    final latRadians = center.latitude * math.pi / 180.0;
    final lngDegrees = viewportKm / (111.0 * math.cos(latRadians).abs()).clamp(0.5, 200.0);
    return (
      LatLng(center.latitude - latDegrees, center.longitude - lngDegrees),
      LatLng(center.latitude + latDegrees, center.longitude + lngDegrees),
    );
  }
}
