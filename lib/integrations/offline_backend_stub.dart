import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/offline_backend.dart';
import 'package:waypoint/utils/logger.dart';

class OfflineBackendImpl implements OfflineBackend {
  @override
  Future<void> initialize() async {
    Log.i('offline.stub', 'initialize (web/no-op)');
  }

  @override
  Future<void> downloadLatLngBounds({
    required ll.LatLng southWest,
    required ll.LatLng northEast,
    required int minZoom,
    required int maxZoom,
    void Function(double p)? onProgress,
  }) async {
    Log.w('offline.stub', 'download skipped (web)');
    onProgress?.call(1.0);
  }

  @override
  Future<List<OfflineRegionInfo>> listRegions() async {
    Log.i('offline.stub', 'listRegions -> []');
    return const [];
  }

  @override
  Future<void> deleteAllRegions() async {
    Log.i('offline.stub', 'deleteAllRegions (noop)');
  }
}
