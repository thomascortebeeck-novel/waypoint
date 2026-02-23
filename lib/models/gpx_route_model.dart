import 'package:latlong2/latlong.dart' as ll;

/// GPX route data imported from a GPX file
class GpxRoute {
  final String? name;
  final List<ll.LatLng> trackPoints; // Full resolution points
  final List<ll.LatLng> simplifiedPoints; // Downsampled for map rendering (~200-300 points)
  final double totalDistanceKm;
  final double? totalElevationGainM;
  final Duration? estimatedDuration; // From GPX time data if available
  final LatLngBounds bounds; // For camera positioning
  final DateTime importedAt;
  final String fileName; // Original filename for reference

  GpxRoute({
    this.name,
    required this.trackPoints,
    required this.simplifiedPoints,
    required this.totalDistanceKm,
    this.totalElevationGainM,
    this.estimatedDuration,
    required this.bounds,
    required this.importedAt,
    required this.fileName,
  });

  /// Create bounds from track points
  static LatLngBounds createBounds(List<ll.LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        ll.LatLng(0, 0),
        ll.LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
  }

  /// Convert to Firestore-safe JSON format
  /// Only stores simplified points to reduce document size
  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'trackPoints': simplifiedPoints.map((p) => {
        'lat': p.latitude,
        'lng': p.longitude,
      }).toList(),
      'totalDistanceKm': totalDistanceKm,
      if (totalElevationGainM != null) 'totalElevationGainM': totalElevationGainM,
      if (estimatedDuration != null) 
        'estimatedDuration': _formatDuration(estimatedDuration!),
      'bounds': {
        'south': bounds.south,
        'west': bounds.west,
        'north': bounds.north,
        'east': bounds.east,
      },
      'importedAt': importedAt.toIso8601String(),
      'fileName': fileName,
    };
  }

  /// Parse from Firestore JSON format
  factory GpxRoute.fromJson(Map<String, dynamic> json) {
    final trackPointsJson = json['trackPoints'] as List? ?? [];
    final trackPoints = trackPointsJson.map((p) {
      return ll.LatLng(
        (p['lat'] as num).toDouble(),
        (p['lng'] as num).toDouble(),
      );
    }).toList();

    final boundsJson = json['bounds'] as Map<String, dynamic>?;
    LatLngBounds bounds;
    if (boundsJson != null) {
      bounds = LatLngBounds(
        ll.LatLng(
          (boundsJson['south'] as num).toDouble(),
          (boundsJson['west'] as num).toDouble(),
        ),
        ll.LatLng(
          (boundsJson['north'] as num).toDouble(),
          (boundsJson['east'] as num).toDouble(),
        ),
      );
    } else {
      bounds = createBounds(trackPoints);
    }

    Duration? estimatedDuration;
    final durationStr = json['estimatedDuration'] as String?;
    if (durationStr != null) {
      estimatedDuration = _parseDuration(durationStr);
    }

    return GpxRoute(
      name: json['name'] as String?,
      trackPoints: trackPoints, // Use simplified points as track points when loading from Firestore
      simplifiedPoints: trackPoints,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      totalElevationGainM: (json['totalElevationGainM'] as num?)?.toDouble(),
      estimatedDuration: estimatedDuration,
      bounds: bounds,
      importedAt: DateTime.parse(json['importedAt'] as String),
      fileName: json['fileName'] as String,
    );
  }

  GpxRoute copyWith({
    String? name,
    List<ll.LatLng>? trackPoints,
    List<ll.LatLng>? simplifiedPoints,
    double? totalDistanceKm,
    double? totalElevationGainM,
    Duration? estimatedDuration,
    LatLngBounds? bounds,
    DateTime? importedAt,
    String? fileName,
  }) {
    return GpxRoute(
      name: name ?? this.name,
      trackPoints: trackPoints ?? this.trackPoints,
      simplifiedPoints: simplifiedPoints ?? this.simplifiedPoints,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalElevationGainM: totalElevationGainM ?? this.totalElevationGainM,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      bounds: bounds ?? this.bounds,
      importedAt: importedAt ?? this.importedAt,
      fileName: fileName ?? this.fileName,
    );
  }

  /// Format duration as "6h 30m"
  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Parse duration from "6h 30m" format
  static Duration _parseDuration(String durationStr) {
    final hoursMatch = RegExp(r'(\d+)h').firstMatch(durationStr);
    final minutesMatch = RegExp(r'(\d+)m').firstMatch(durationStr);
    
    final hours = hoursMatch != null ? int.parse(hoursMatch.group(1)!) : 0;
    final minutes = minutesMatch != null ? int.parse(minutesMatch.group(1)!) : 0;
    
    return Duration(hours: hours, minutes: minutes);
  }
}

/// Bounds for a geographic area
class LatLngBounds {
  final ll.LatLng southwest;
  final ll.LatLng northeast;

  LatLngBounds(this.southwest, this.northeast);

  double get south => southwest.latitude;
  double get west => southwest.longitude;
  double get north => northeast.latitude;
  double get east => northeast.longitude;

  ll.LatLng get center => ll.LatLng(
    (south + north) / 2,
    (west + east) / 2,
  );
}

