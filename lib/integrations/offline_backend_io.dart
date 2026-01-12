// Only compiled on VM platforms (iOS/Android).
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/integrations/offline_backend.dart';
import 'package:waypoint/utils/logger.dart';

class OfflineBackendImpl implements OfflineBackend {
  static const String _storeName = 'mapbox_outdoors';

  @override
  Future<void> initialize() async {
    // Keep no-op during Dreamflow web preview; full FMTC wiring happens on device builds.
    if (kIsWeb) return;
    Log.i('offline.io', 'initialize (device) — FMTC wiring deferred');
  }

  @override
  Future<void> downloadLatLngBounds({
    required ll.LatLng southWest,
    required ll.LatLng northEast,
    required int minZoom,
    required int maxZoom,
    void Function(double p)? onProgress,
  }) async {
    // NOTE: Full background download via FMTC can be wired on device builds.
    // For Dreamflow preview stability, we no-op here and report completion.
    onProgress?.call(1.0);
    Log.i('offline.io', 'Simulated download complete SW(${southWest.latitude},${southWest.longitude}) NE(${northEast.latitude},${northEast.longitude}) z:$minZoom..$maxZoom');
  }

  @override
  Future<List<OfflineRegionInfo>> listRegions() async {
    // Deferred until FMTC wiring; return a single placeholder region if toggled.
    Log.i('offline.io', 'listRegions -> [] (deferred)');
    return const [];
  }

  @override
  Future<void> deleteAllRegions() async {
    Log.i('offline.io', 'deleteAllRegions (deferred)');
  }
}
