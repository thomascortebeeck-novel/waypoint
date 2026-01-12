import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/offline_backend.dart';
export 'package:waypoint/integrations/offline_backend.dart' show OfflineRegionInfo;

// Conditional import selects the proper backend at compile-time.
import 'package:waypoint/integrations/offline_backend_stub.dart'
    if (dart.library.io) 'package:waypoint/integrations/offline_backend_io.dart';
import 'package:waypoint/utils/logger.dart';

class OfflineTilesManager {
  static final OfflineTilesManager _instance = OfflineTilesManager._internal();
  factory OfflineTilesManager() => _instance;
  OfflineTilesManager._internal();

  final OfflineBackend _backend = OfflineBackendImpl();

  Future<void> initialize() async {
    Log.i('offline', 'Using backend: ${_backend.runtimeType}');
    await _backend.initialize();
  }

  Future<void> downloadLatLngBounds({
    required ll.LatLng southWest,
    required ll.LatLng northEast,
    required int minZoom,
    required int maxZoom,
    void Function(double progress)? onProgress,
  }) => _backend.downloadLatLngBounds(southWest: southWest, northEast: northEast, minZoom: minZoom, maxZoom: maxZoom, onProgress: onProgress);

  Future<List<OfflineRegionInfo>> listRegions() => _backend.listRegions();
  Future<void> deleteAllRegions() => _backend.deleteAllRegions();
}
