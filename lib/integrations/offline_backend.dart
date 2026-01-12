import 'package:latlong2/latlong.dart' as ll;

abstract class OfflineBackend {
  Future<void> initialize();
  Future<void> downloadLatLngBounds({
    required ll.LatLng southWest,
    required ll.LatLng northEast,
    required int minZoom,
    required int maxZoom,
    void Function(double progress)? onProgress,
  });
  Future<List<OfflineRegionInfo>> listRegions();
  Future<void> deleteAllRegions();
}

class OfflineRegionInfo {
  final String name;
  final int tileCount;
  final int sizeBytes;
  const OfflineRegionInfo({required this.name, required this.tileCount, required this.sizeBytes});

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
