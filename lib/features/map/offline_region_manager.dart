import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/utils/logger.dart';

/// Manages offline map regions using Mapbox SDK's native offline capabilities
/// This provides full vector tile quality offline, including 3D terrain
class OfflineRegionManager {
  static final OfflineRegionManager _instance = OfflineRegionManager._internal();
  factory OfflineRegionManager() => _instance;
  OfflineRegionManager._internal();

  TileStore? _tileStore;
  OfflineManager? _offlineManager;
  
  final _downloadProgressController = StreamController<DownloadProgress>.broadcast();
  final _regionListController = StreamController<List<OfflineRegion>>.broadcast();
  
  /// Stream of download progress updates
  Stream<DownloadProgress> get downloadProgress => _downloadProgressController.stream;
  
  /// Stream of available offline regions
  Stream<List<OfflineRegion>> get regions => _regionListController.stream;
  
  /// Currently downloading region IDs
  final Set<String> _activeDownloads = {};
  
  /// Active download cancelables for cancellation support
  final Map<String, Cancelable?> _activeCancelables = {};
  
  /// Cached list of regions
  List<OfflineRegion> _cachedRegions = [];

  /// Initialize the offline manager
  Future<void> initialize() async {
    if (kIsWeb) {
      Log.w('offline', '⚠️ Offline regions not supported on web');
      return;
    }

    try {
      _tileStore = await TileStore.createDefault();
      _offlineManager = await OfflineManager.create();
      
      // Load existing regions
      await refreshRegions();
      
      Log.i('offline', '✅ Offline manager initialized');
    } catch (e) {
      Log.e('offline', 'Failed to initialize offline manager', e);
    }
  }

  /// Download an offline region for a route
  /// 
  /// [regionId] - Unique identifier for this region
  /// [routePoints] - The route coordinates to download around
  /// [bufferKm] - Buffer distance around route in kilometers (default 2km)
  /// [minZoom] - Minimum zoom level to download (default 10)
  /// [maxZoom] - Maximum zoom level to download (default 16)
  Future<bool> downloadRouteRegion({
    required String regionId,
    required List<LatLng> routePoints,
    double bufferKm = 2.0,
    int minZoom = 10,
    int maxZoom = 16,
    String? displayName,
  }) async {
    if (_tileStore == null || _offlineManager == null) {
      Log.e('offline', 'Offline manager not initialized');
      return false;
    }

    if (_activeDownloads.contains(regionId)) {
      Log.w('offline', 'Download already in progress for region: $regionId');
      return false;
    }

    // Check network connectivity before attempting download
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _downloadProgressController.add(DownloadProgress(
          regionId: regionId,
          phase: DownloadPhase.error,
          progress: 0,
          message: 'No internet connection. Please connect and try again.',
        ));
        Log.w('offline', '⚠️ No internet connection for download');
        return false;
      }
    } catch (e) {
      Log.w('offline', 'Could not check connectivity: $e');
      // Continue anyway - the download will fail if there's no network
    }

    try{
      _activeDownloads.add(regionId);
      
      // Calculate bounding box with buffer
      final bounds = _calculateBoundsWithBuffer(routePoints, bufferKm);
      
      Log.i('offline', '📥 Starting download for region: $regionId');
      Log.i('offline', '   Bounds: ${bounds.southwest} to ${bounds.northeast}');
      Log.i('offline', '   Zoom: $minZoom - $maxZoom');

      // Step 1: Download style pack (fonts, sprites, glyphs)
      _downloadProgressController.add(DownloadProgress(
        regionId: regionId,
        phase: DownloadPhase.preparingStyle,
        progress: 0,
        message: 'Preparing map style...',
      ));

      try {
        await _offlineManager!.loadStylePack(
          mapboxStyleUri,
          StylePackLoadOptions(
            glyphsRasterizationMode: GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
            acceptExpired: false,
          ),
          (progress) {
            _downloadProgressController.add(DownloadProgress(
              regionId: regionId,
              phase: DownloadPhase.downloadingStyle,
              progress: progress.completedResourceCount / 
                       (progress.requiredResourceCount > 0 ? progress.requiredResourceCount : 1),
              message: 'Downloading style assets...',
            ));
          },
        );
      } catch (e) {
        _activeDownloads.remove(regionId);
        _downloadProgressController.add(DownloadProgress(
          regionId: regionId,
          phase: DownloadPhase.error,
          progress: 0,
          message: 'Failed to download map style. Please try again.',
          error: e,
        ));
        Log.e('offline', 'Style pack download failed for region: $regionId', e);
        return false;
      }

      // Step 2: Download tile region
      _downloadProgressController.add(DownloadProgress(
        regionId: regionId,
        phase: DownloadPhase.downloadingTiles,
        progress: 0,
        message: 'Downloading map tiles...',
      ));

      // Create geometry from bounds
      final geometry = _boundsToPolygon(bounds);

      await _tileStore!.loadTileRegion(
        regionId,
        TileRegionLoadOptions(
          geometry: geometry,
          descriptorsOptions: [
            TilesetDescriptorOptions(
              styleURI: mapboxStyleUri,
              minZoom: minZoom,
              maxZoom: maxZoom,
            ),
          ],
          networkRestriction: NetworkRestriction.NONE,
          acceptExpired: false,
          averageBytesPerSecond: null, // No throttling
        ),
        (progress) {
          final totalTiles = progress.requiredResourceCount;
          final completedTiles = progress.completedResourceCount;
          final progressPercent = totalTiles > 0 ? completedTiles / totalTiles : 0.0;
          
          _downloadProgressController.add(DownloadProgress(
            regionId: regionId,
            phase: DownloadPhase.downloadingTiles,
            progress: progressPercent,
            completedTiles: completedTiles,
            totalTiles: totalTiles,
            message: 'Downloading tiles: $completedTiles / $totalTiles',
          ));
        },
      );

      // Step 3: Save metadata
      await _saveRegionMetadata(regionId, displayName ?? regionId, bounds, routePoints.length);

      _activeDownloads.remove(regionId);
      
      _downloadProgressController.add(DownloadProgress(
        regionId: regionId,
        phase: DownloadPhase.complete,
        progress: 1.0,
        message: 'Download complete!',
      ));

      // Refresh regions list
      await refreshRegions();

      Log.i('offline', '✅ Region download complete: $regionId');
      return true;
    } catch (e) {
      _activeDownloads.remove(regionId);
      
      _downloadProgressController.add(DownloadProgress(
        regionId: regionId,
        phase: DownloadPhase.error,
        progress: 0,
        message: 'Download failed: ${e.toString()}',
        error: e,
      ));

      Log.e('offline', 'Failed to download region: $regionId', e);
      return false;
    }
  }

  /// Download an offline region by bounding box
  Future<bool> downloadBoundsRegion({
    required String regionId,
    required LatLngBounds bounds,
    int minZoom = 10,
    int maxZoom = 16,
    String? displayName,
  }) async {
    // Convert bounds to route points (corners) for the existing method
    final routePoints = [
      bounds.southwest,
      LatLng(bounds.southwest.latitude, bounds.northeast.longitude),
      bounds.northeast,
      LatLng(bounds.northeast.latitude, bounds.southwest.longitude),
    ];
    
    return downloadRouteRegion(
      regionId: regionId,
      routePoints: routePoints,
      bufferKm: 0, // No buffer needed, bounds are exact
      minZoom: minZoom,
      maxZoom: maxZoom,
      displayName: displayName,
    );
  }

  /// Delete an offline region
  Future<bool> deleteRegion(String regionId) async {
    if (_tileStore == null) return false;

    try {
      await _tileStore!.removeRegion(regionId);
      await _deleteRegionMetadata(regionId);
      await refreshRegions();
      
      Log.i('offline', '🗑️ Region deleted: $regionId');
      return true;
    } catch (e) {
      Log.e('offline', 'Failed to delete region: $regionId', e);
      return false;
    }
  }

  /// Get all downloaded regions
  Future<List<OfflineRegion>> getRegions() async {
    await refreshRegions();
    return _cachedRegions;
  }

  /// Refresh the list of downloaded regions
  Future<void> refreshRegions() async {
    if (_tileStore == null) return;

    try {
      final tileRegions = await _tileStore!.allTileRegions();
      
      _cachedRegions = [];
      for (final region in tileRegions) {
        final metadata = await _loadRegionMetadata(region.id);
        _cachedRegions.add(OfflineRegion(
          id: region.id,
          displayName: metadata?['displayName'] ?? region.id,
          completedSize: region.completedResourceSize,
          completedTiles: region.completedResourceCount,
          bounds: metadata?['bounds'],
          downloadedAt: metadata?['downloadedAt'],
        ));
      }
      
      _regionListController.add(_cachedRegions);
    } catch (e) {
      Log.e('offline', 'Failed to refresh regions', e);
    }
  }

  /// Check if a region is downloaded
  Future<bool> isRegionDownloaded(String regionId) async {
    if (_tileStore == null) return false;
    
    try {
      final region = await _tileStore!.tileRegion(regionId);
      return region != null && region.completedResourceCount > 0;
    } catch (e) {
      return false;
    }
  }

  /// Estimate download size for a region
  Future<EstimatedSize?> estimateRegionSize({
    required List<LatLng> routePoints,
    double bufferKm = 2.0,
    int minZoom = 10,
    int maxZoom = 16,
  }) async {
    // Rough estimation: ~50KB per tile at zoom 14
    // Number of tiles grows by 4x for each zoom level
    
    final bounds = _calculateBoundsWithBuffer(routePoints, bufferKm);
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;
    
    int totalTiles = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final tilesPerDegree = (1 << z) / 360.0;
      final tilesX = (lngDiff * tilesPerDegree).ceil();
      final tilesY = (latDiff * tilesPerDegree).ceil();
      totalTiles += tilesX * tilesY;
    }
    
    // Estimate ~50KB per tile on average
    final estimatedBytes = totalTiles * 50 * 1024;
    
    return EstimatedSize(
      tiles: totalTiles,
      bytes: estimatedBytes,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  /// Calculate bounding box with buffer around route points
  LatLngBounds _calculateBoundsWithBuffer(List<LatLng> points, double bufferKm) {
    if (points.isEmpty) {
      throw ArgumentError('Route points cannot be empty');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Add buffer (rough conversion: 1 degree ≈ 111km)
    final bufferDegrees = bufferKm / 111.0;
    
    return LatLngBounds(
      southwest: LatLng(minLat - bufferDegrees, minLng - bufferDegrees),
      northeast: LatLng(maxLat + bufferDegrees, maxLng + bufferDegrees),
    );
  }

  /// Convert bounds to GeoJSON polygon for tile download
  /// Returns a Map that the Mapbox SDK can use as geometry
  Map<String?, Object?> _boundsToPolygon(LatLngBounds bounds) {
    return {
      'type': 'Polygon',
      'coordinates': [[
        [bounds.southwest.longitude, bounds.southwest.latitude],
        [bounds.northeast.longitude, bounds.southwest.latitude],
        [bounds.northeast.longitude, bounds.northeast.latitude],
        [bounds.southwest.longitude, bounds.northeast.latitude],
        [bounds.southwest.longitude, bounds.southwest.latitude],
      ]],
    };
  }

  // Metadata storage helpers using shared_preferences
  Future<void> _saveRegionMetadata(String regionId, String displayName, LatLngBounds bounds, int routePointCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = {
        'displayName': displayName,
        'downloadedAt': DateTime.now().toIso8601String(),
        'bounds': {
          'southwest': {'lat': bounds.southwest.latitude, 'lng': bounds.southwest.longitude},
          'northeast': {'lat': bounds.northeast.latitude, 'lng': bounds.northeast.longitude},
        },
        'routePointCount': routePointCount,
      };
      await prefs.setString('offline_region_$regionId', jsonEncode(metadata));
    } catch (e) {
      Log.e('offline', 'Failed to save region metadata', e);
    }
  }

  Future<Map<String, dynamic>?> _loadRegionMetadata(String regionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataJson = prefs.getString('offline_region_$regionId');
      if (metadataJson == null) return null;
      
      final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
      
      // Parse bounds if available
      LatLngBounds? bounds;
      if (metadata['bounds'] != null) {
        final boundsData = metadata['bounds'] as Map<String, dynamic>;
        final sw = boundsData['southwest'] as Map<String, dynamic>;
        final ne = boundsData['northeast'] as Map<String, dynamic>;
        bounds = LatLngBounds(
          southwest: LatLng(sw['lat'] as double, sw['lng'] as double),
          northeast: LatLng(ne['lat'] as double, ne['lng'] as double),
        );
      }
      
      return {
        'displayName': metadata['displayName'],
        'downloadedAt': metadata['downloadedAt'] != null 
          ? DateTime.parse(metadata['downloadedAt'] as String) 
          : null,
        'bounds': bounds,
        'routePointCount': metadata['routePointCount'],
      };
    } catch (e) {
      Log.e('offline', 'Failed to load region metadata', e);
      return null;
    }
  }

  Future<void> _deleteRegionMetadata(String regionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_region_$regionId');
    } catch (e) {
      Log.e('offline', 'Failed to delete region metadata', e);
    }
  }

  /// Cancel an active download
  Future<void> cancelDownload(String regionId) async {
    final cancelable = _activeCancelables[regionId];
    if (cancelable != null) {
      try {
        cancelable.cancel();
        _activeCancelables.remove(regionId);
        _activeDownloads.remove(regionId);
        
        _downloadProgressController.add(DownloadProgress(
          regionId: regionId,
          phase: DownloadPhase.cancelled,
          progress: 0,
          message: 'Download cancelled',
        ));
        
        Log.i('offline', '🚫 Download cancelled: $regionId');
      } catch (e) {
        Log.e('offline', 'Failed to cancel download', e);
      }
    }
  }

  void dispose() {
    // Cancel all active downloads
    for (final regionId in _activeDownloads.toList()) {
      cancelDownload(regionId);
    }
    
    _downloadProgressController.close();
    _regionListController.close();
    
    // Clear references
    _tileStore = null;
    _offlineManager = null;
  }
}

/// Represents a downloaded offline region
class OfflineRegion {
  final String id;
  final String displayName;
  final int completedSize; // bytes
  final int completedTiles;
  final LatLngBounds? bounds;
  final DateTime? downloadedAt;

  const OfflineRegion({
    required this.id,
    required this.displayName,
    required this.completedSize,
    required this.completedTiles,
    this.bounds,
    this.downloadedAt,
  });

  String get formattedSize {
    if (completedSize < 1024) return '$completedSize B';
    if (completedSize < 1024 * 1024) return '${(completedSize / 1024).toStringAsFixed(1)} KB';
    return '${(completedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Download progress information
class DownloadProgress {
  final String regionId;
  final DownloadPhase phase;
  final double progress; // 0.0 to 1.0
  final String message;
  final int? completedTiles;
  final int? totalTiles;
  final Object? error;

  const DownloadProgress({
    required this.regionId,
    required this.phase,
    required this.progress,
    required this.message,
    this.completedTiles,
    this.totalTiles,
    this.error,
  });

  int get progressPercent => (progress * 100).round();
}

/// Download phase
enum DownloadPhase {
  preparingStyle,
  downloadingStyle,
  downloadingTiles,
  complete,
  cancelled,
  error,
}

/// Estimated download size
class EstimatedSize {
  final int tiles;
  final int bytes;
  final int minZoom;
  final int maxZoom;

  const EstimatedSize({
    required this.tiles,
    required this.bytes,
    required this.minZoom,
    required this.maxZoom,
  });

  String get formattedSize {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Latitude/Longitude bounds
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds({
    required this.southwest,
    required this.northeast,
  });
}
