import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:waypoint/integrations/offline_tile_provider.dart';
import 'package:latlong2/latlong.dart';
// Mapbox native widget can be enabled in a follow-up with exact SDK API.
import 'package:waypoint/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/integrations/offline_manager.dart';
import 'package:waypoint/presentation/map/offline_manager_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    Log.i('map', 'MapScreen init, center=${_center.latitude},${_center.longitude}, web=$kIsWeb');
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
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/512/{z}/{x}/{y}?access_token=$mapboxPublicToken',
                userAgentPackageName: 'com.waypoint.app',
                tileProvider: kIsWeb ? NetworkTileProvider() : tileProviderOrNetwork(),
              ),
              PolylineLayer(polylines: [
                Polyline(points: [const LatLng(60.9, 8.4), const LatLng(60.95, 8.45), const LatLng(61.0, 8.5), const LatLng(61.05, 8.55), const LatLng(61.1, 8.6)], strokeWidth: 4.0, color: context.colors.primary)
              ]),
              MarkerLayer(markers: [
                Marker(point: _center, width: 40, height: 40, child: _puck(context))
              ])
            ],
          ),

          // 2. Top Bar (Back + Stats)
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

          // 3. Bottom Controls (Emergency + Info)
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

// Mobile Mapbox renderer placeholder. On device builds, replace with mapbox_maps_flutter MapWidget
class _MobileMapboxView extends StatelessWidget {
  final LatLng initial;
  const _MobileMapboxView({required this.initial});

  @override
  Widget build(BuildContext context) {
    if (!hasValidMapboxToken) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Provide MAPBOX_PUBLIC_TOKEN via --dart-define to enable Mapbox map on device.', style: context.textStyles.bodySmall)));
    }
    return Container(color: Colors.black12, child: const Center(child: Text('Mapbox map (device build)', style: TextStyle(fontSize: 12))));
  }
}
