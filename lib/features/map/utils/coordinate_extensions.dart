import 'package:latlong2/latlong.dart';

/// Extension to ensure consistent coordinate format conversion
/// 
/// Mapbox/GeoJSON uses [longitude, latitude] format
/// Flutter/LatLng uses (latitude, longitude) format
/// 
/// This extension helps prevent coordinate order mistakes
extension PositionExt on LatLng {
  /// Convert to Mapbox/GeoJSON format: [longitude, latitude]
  /// Use this when passing coordinates to Mapbox GL JS
  List<double> toLngLat() => [longitude, latitude];
  
  /// Convert to Flutter format: (latitude, longitude)
  /// This is already the default for LatLng, but included for clarity
  List<double> toLatLng() => [latitude, longitude];
  
  /// Validate coordinates are within valid ranges
  bool get isValid {
    return latitude >= -90 && latitude <= 90 &&
           longitude >= -180 && longitude <= 180;
  }
  
  /// Create from Mapbox/GeoJSON format: [longitude, latitude]
  static LatLng fromLngLat(List<double> coords) {
    if (coords.length < 2) {
      throw ArgumentError('Coordinates must have at least 2 elements [lng, lat]');
    }
    return LatLng(coords[1], coords[0]); // lat, lng
  }
}

