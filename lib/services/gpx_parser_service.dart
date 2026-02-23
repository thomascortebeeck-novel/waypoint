import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:waypoint/models/gpx_route_model.dart';
import 'package:waypoint/utils/haversine_utils.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for parsing GPX files and extracting route data
class GpxParserService {
  /// Parse a GPX file and return a GpxRoute object
  /// 
  /// [file] - The GPX file to parse (works on mobile/desktop)
  /// Returns GpxRoute with parsed track points, distance, elevation, etc.
  Future<GpxRoute> parseGpxFile(File file) async {
    Log.i('gpx_parser', '📁 Parsing GPX file: ${file.path}');
    final content = await file.readAsString();
    final fileName = file.path.split('/').last.split('\\').last; // Handle both / and \ separators
    Log.i('gpx_parser', '📄 File size: ${content.length} characters');
    return parseGpxString(content, fileName: fileName);
  }

  /// Parse a GPX file from bytes (for web compatibility)
  /// 
  /// [bytes] - The GPX file bytes
  /// [fileName] - Original filename
  /// Returns GpxRoute with parsed track points, distance, elevation, etc.
  Future<GpxRoute> parseGpxBytes(Uint8List bytes, String fileName) async {
    Log.i('gpx_parser', '📁 Parsing GPX file from bytes: $fileName (${bytes.length} bytes)');
    // Convert bytes to string, handling UTF-8 encoding
    final content = String.fromCharCodes(bytes);
    Log.i('gpx_parser', '📄 Content size: ${content.length} characters');
    return parseGpxString(content, fileName: fileName);
  }

  /// Parse GPX content from a string
  /// 
  /// [gpxContent] - XML content of the GPX file
  /// [fileName] - Original filename for reference
  Future<GpxRoute> parseGpxString(String gpxContent, {String? fileName}) async {
    Log.i('gpx_parser', '🔍 Starting GPX parsing for: ${fileName ?? "unknown"}');
    
    // Log first 500 characters to see the XML structure
    final preview = gpxContent.length > 500 
        ? '${gpxContent.substring(0, 500)}...' 
        : gpxContent;
    Log.i('gpx_parser', '📋 XML preview (first 500 chars):\n$preview');
    
    // Check for GPX root element
    if (!gpxContent.contains('<gpx') && !gpxContent.contains('<GPX')) {
      Log.e('gpx_parser', '❌ No <gpx> root element found in XML');
      throw Exception('Invalid GPX file: no <gpx> root element found');
    }
    
    // Preprocess XML to handle namespace issues
    Log.i('gpx_parser', '🧹 Preprocessing XML...');
    final cleanedContent = _preprocessGpxXml(gpxContent);
    Log.i('gpx_parser', '✅ Preprocessing complete');
    
    // Log namespace info
    final hasNamespace = cleanedContent.contains('xmlns=');
    Log.i('gpx_parser', '🏷️  Has namespace declaration: $hasNamespace');
    if (hasNamespace) {
      final namespaceMatch = RegExp(r'xmlns[^=]*="([^"]*)"').firstMatch(cleanedContent);
      if (namespaceMatch != null) {
        Log.i('gpx_parser', '🏷️  Namespace: ${namespaceMatch.group(1)}');
      }
    }
    
    Gpx gpx;
    try {
      Log.i('gpx_parser', '📖 Attempting initial parse with GpxReader...');
      gpx = GpxReader().fromString(cleanedContent);
      Log.i('gpx_parser', '✅ Initial parse successful!');
    } catch (e, stack) {
      Log.e('gpx_parser', '❌ Initial parse failed', e, stack);
      
      // Check if it's a namespace-related error
      final errorStr = e.toString().toLowerCase();
      final isNamespaceError = errorStr.contains('namespace') || errorStr.contains('_namespace');
      Log.i('gpx_parser', '🔍 Error type - Namespace error: $isNamespaceError');
      Log.i('gpx_parser', '🔍 Full error: ${e.toString()}');
      
      if (isNamespaceError) {
        // Try with namespace normalization
        Log.i('gpx_parser', '🔄 Attempting namespace normalization...');
        final normalizedContent = _normalizeNamespaces(cleanedContent);
        Log.i('gpx_parser', '✅ Namespace normalization complete');
        
        // Log normalized namespace
        final normalizedNamespaceMatch = RegExp(r'xmlns[^=]*="([^"]*)"').firstMatch(normalizedContent);
        if (normalizedNamespaceMatch != null) {
          Log.i('gpx_parser', '🏷️  Normalized namespace: ${normalizedNamespaceMatch.group(1)}');
        }
        
        try {
          Log.i('gpx_parser', '📖 Attempting parse with normalized namespaces...');
          gpx = GpxReader().fromString(normalizedContent);
          Log.i('gpx_parser', '✅ Parse with normalized namespaces successful!');
        } catch (e2, stack2) {
          Log.e('gpx_parser', '❌ Parse with normalized namespaces failed', e2, stack2);
          
          // If that also fails, try removing namespaces entirely
          Log.i('gpx_parser', '🔄 Attempting namespace removal...');
          final noNamespaceContent = _removeNamespaces(normalizedContent);
          Log.i('gpx_parser', '✅ Namespace removal complete');
          
          try {
            Log.i('gpx_parser', '📖 Attempting parse without namespaces...');
            gpx = GpxReader().fromString(noNamespaceContent);
            Log.i('gpx_parser', '✅ Parse without namespaces successful!');
          } catch (e3, stack3) {
            Log.e('gpx_parser', '❌ All parsing attempts failed', e3, stack3);
            throw Exception(
              'Failed to parse GPX file due to namespace issues. '
              'Please ensure your GPX file uses standard GPX 1.1 format. '
              'Original error: ${e.toString()}, '
              'Normalized error: ${e2.toString()}, '
              'No namespace error: ${e3.toString()}'
            );
          }
        }
      } else {
        // Non-namespace error, rethrow with context
        Log.e('gpx_parser', '❌ Non-namespace parsing error', e, stack);
        throw Exception(
          'Failed to parse GPX file: ${e.toString()}. '
          'Please ensure the file is a valid GPX file.'
        );
      }
    }
    
    // Extract track points (primary format: <trk><trkseg><trkpt>)
    List<ll.LatLng> trackPoints = [];
    String? routeName;
    List<double?> elevations = [];
    List<DateTime?> timestamps = [];

    // Try to get route name from metadata
    routeName = gpx.metadata?.name;
    Log.i('gpx_parser', '📝 Route name: ${routeName ?? "unnamed"}');
    
    // Extract track points from tracks using typed API
    Log.i('gpx_parser', '📍 Extracting track points...');
    try {
      if (gpx.trks.isNotEmpty) {
        Log.i('gpx_parser', '🎯 Found ${gpx.trks.length} tracks');
        
        // Get route name from first track if not already set
        if (routeName == null && gpx.trks.first.name != null) {
          routeName = gpx.trks.first.name;
        }
        
        // Extract points from all tracks
        for (final trk in gpx.trks) {
          for (final seg in trk.trksegs) {
            for (final pt in seg.trkpts) {
              if (pt.lat != null && pt.lon != null) {
                trackPoints.add(ll.LatLng(
                  pt.lat!,
                  pt.lon!,
                ));
                elevations.add(pt.ele);
                timestamps.add(pt.time);
              }
            }
          }
        }
        Log.i('gpx_parser', '✅ Extracted ${trackPoints.length} track points from tracks');
      } else {
        Log.i('gpx_parser', '⚠️  No tracks found in GPX file');
      }
    } catch (e, stack) {
      // Tracks access failed, will try routes below
      Log.w('gpx_parser', '⚠️  Failed to extract tracks: ${e.toString()}');
      Log.w('gpx_parser', 'Stack trace: $stack');
    }

    // Fallback: Extract route points if no tracks found (<rte><rtept>)
    if (trackPoints.isEmpty) {
      Log.i('gpx_parser', '🔄 No tracks found, trying routes...');
      try {
        if (gpx.rtes.isNotEmpty) {
          Log.i('gpx_parser', '🎯 Found ${gpx.rtes.length} routes');
          
          // Extract points from all routes
          for (final rte in gpx.rtes) {
            // Get route name if not already set
            if (routeName == null && rte.name != null) {
              routeName = rte.name;
            }
            
            // Extract points from route
            for (final pt in rte.rtepts) {
              if (pt.lat != null && pt.lon != null) {
                trackPoints.add(ll.LatLng(
                  pt.lat!,
                  pt.lon!,
                ));
                elevations.add(pt.ele);
                timestamps.add(pt.time);
              }
            }
          }
          Log.i('gpx_parser', '✅ Extracted ${trackPoints.length} route points from routes');
        } else {
          Log.i('gpx_parser', '⚠️  No routes found in GPX file');
        }
      } catch (e, stack) {
        // Routes access also failed
        Log.e('gpx_parser', '❌ Failed to extract routes', e, stack);
      }
    }

    if (trackPoints.isEmpty) {
      Log.e('gpx_parser', '❌ No track points or route points found in GPX file');
      throw Exception('No track points or route points found in GPX file');
    }
    
    Log.i('gpx_parser', '✅ Successfully extracted ${trackPoints.length} points');

    // Calculate total distance using direct Haversine calculation
    // This avoids any potential issues with HaversineUtils
    Log.i('gpx_parser', '📏 Calculating total distance from ${trackPoints.length} points...');
    double totalDistanceKm = 0.0;
    int validSegments = 0;
    for (int i = 0; i < trackPoints.length - 1; i++) {
      final from = trackPoints[i];
      final to = trackPoints[i + 1];
      
      // Log first few segments for debugging
      if (i < 3) {
        Log.i('gpx_parser', '  Segment $i: (${from.latitude}, ${from.longitude}) -> (${to.latitude}, ${to.longitude})');
      }
      
      // Direct Haversine calculation
      final segmentDistance = _haversineDistanceKm(from, to);
      if (segmentDistance > 0) {
        validSegments++;
      }
      totalDistanceKm += segmentDistance;
      
      // Log first few segment distances
      if (i < 3) {
        Log.i('gpx_parser', '  Segment $i distance: ${segmentDistance.toStringAsFixed(4)} km');
      }
    }
    Log.i('gpx_parser', '📏 Total distance: ${totalDistanceKm.toStringAsFixed(2)} km (${validSegments}/${trackPoints.length - 1} valid segments)');
    
    // Warn if distance is suspiciously low
    if (totalDistanceKm < 0.001 && trackPoints.length > 10) {
      Log.w('gpx_parser', '⚠️  Warning: Distance is very low (${totalDistanceKm.toStringAsFixed(4)} km) for ${trackPoints.length} points. Check coordinate access.');
    }

    // Calculate elevation gain (sum of positive elevation changes)
    double? totalElevationGainM;
    if (elevations.any((e) => e != null)) {
      double elevationGain = 0.0;
      double? prevElevation;
      for (final elevation in elevations) {
        if (elevation != null && prevElevation != null) {
          final change = elevation - prevElevation;
          if (change > 0) {
            elevationGain += change;
          }
        }
        if (elevation != null) {
          prevElevation = elevation;
        }
      }
      totalElevationGainM = elevationGain;
    }

    // Calculate estimated duration from time data if available
    Duration? estimatedDuration;
    if (timestamps.any((t) => t != null)) {
      final validTimestamps = timestamps.whereType<DateTime>().toList();
      if (validTimestamps.length >= 2) {
        final start = validTimestamps.first;
        final end = validTimestamps.last;
        estimatedDuration = end.difference(start);
      }
    }

    // Simplify/downsample polyline if > 500 points
    Log.i('gpx_parser', '🔧 Simplifying polyline (${trackPoints.length} -> max 300 points)...');
    final simplifiedPoints = _simplifyPolyline(trackPoints, maxPoints: 300);
    Log.i('gpx_parser', '✅ Simplified to ${simplifiedPoints.length} points');

    // Create bounds
    final bounds = GpxRoute.createBounds(trackPoints);
    Log.i('gpx_parser', '🗺️  Bounds: ${bounds.south},${bounds.west} to ${bounds.north},${bounds.east}');

    Log.i('gpx_parser', '✅ GPX parsing complete!');
    return GpxRoute(
      name: routeName,
      trackPoints: trackPoints,
      simplifiedPoints: simplifiedPoints,
      totalDistanceKm: totalDistanceKm,
      totalElevationGainM: totalElevationGainM,
      estimatedDuration: estimatedDuration,
      bounds: bounds,
      importedAt: DateTime.now(),
      fileName: fileName ?? 'imported.gpx',
    );
  }

  /// Calculate Haversine distance directly (in km)
  /// This is a fallback to ensure distance calculation works correctly
  double _haversineDistanceKm(ll.LatLng from, ll.LatLng to) {
    const R = 6371.0; // Earth radius in km
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(from.latitude * math.pi / 180) * math.cos(to.latitude * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Simplify polyline using Douglas-Peucker algorithm
  /// Preserves start and end points and important turns
  /// 
  /// [points] - Original track points
  /// [maxPoints] - Maximum number of points in simplified polyline
  List<ll.LatLng> _simplifyPolyline(List<ll.LatLng> points, {int maxPoints = 300}) {
    if (points.length <= maxPoints) {
      return List.from(points);
    }

    // Use Douglas-Peucker with increasing tolerance until under maxPoints
    double tolerance = 0.00005; // ~5m
    var result = _douglasPeucker(points, tolerance);
    
    while (result.length > maxPoints) {
      tolerance *= 2;
      result = _douglasPeucker(points, tolerance);
    }
    
    return result;
  }

  /// Douglas-Peucker algorithm for polyline simplification
  List<ll.LatLng> _douglasPeucker(List<ll.LatLng> points, double tolerance) {
    if (points.length <= 2) return List.from(points);
    
    double maxDist = 0;
    int maxIndex = 0;
    
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistance(points[i], points.first, points.last);
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }
    
    if (maxDist > tolerance) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      final right = _douglasPeucker(points.sublist(maxIndex), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  /// Calculate perpendicular distance from a point to a line segment
  double _perpendicularDistance(ll.LatLng point, ll.LatLng start, ll.LatLng end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final norm = math.sqrt(dx * dx + dy * dy);
    if (norm == 0) {
      return math.sqrt(math.pow(point.longitude - start.longitude, 2) + 
                      math.pow(point.latitude - start.latitude, 2));
    }
    return ((point.longitude - start.longitude) * dy - 
            (point.latitude - start.latitude) * dx).abs() / norm;
  }

  /// Preprocess GPX XML to handle common namespace and encoding issues
  String _preprocessGpxXml(String xml) {
    // Remove BOM if present
    String cleaned = xml;
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1);
    }
    
    // Ensure proper XML declaration
    if (!cleaned.trim().startsWith('<?xml')) {
      cleaned = '<?xml version="1.0" encoding="UTF-8"?>\n$cleaned';
    }
    
    return cleaned;
  }

  /// Normalize XML namespaces to standard GPX 1.1 format
  /// Replaces various namespace declarations with the standard one
  String _normalizeNamespaces(String xml) {
    String cleaned = xml;
    
    // Replace any gpx namespace with the standard GPX 1.1 namespace
    cleaned = cleaned.replaceAll(
      RegExp(r'<gpx([^>]*)xmlns[^=]*="[^"]*"', caseSensitive: false),
      r'<gpx$1xmlns="http://www.topografix.com/GPX/1/1"',
    );
    
    // Ensure standard GPX 1.1 namespace is present
    if (!cleaned.contains('xmlns="http://www.topografix.com/GPX/1/1"')) {
      cleaned = cleaned.replaceFirst(
        RegExp(r'<gpx([^>]*)>', caseSensitive: false),
        r'<gpx$1 xmlns="http://www.topografix.com/GPX/1/1">',
      );
    }
    
    return cleaned;
  }

  /// Remove XML namespaces that may cause parsing issues
  /// This is a last resort fallback when namespace normalization fails
  /// Only removes problematic namespace declarations, preserves XML structure
  String _removeNamespaces(String xml) {
    String cleaned = xml;
    
    // Remove xmlns attributes from root gpx element only
    // This preserves the XML structure while removing namespace issues
    cleaned = cleaned.replaceAll(
      RegExp(r'<gpx([^>]*)\s+xmlns[^=]*="[^"]*"', caseSensitive: false),
      r'<gpx$1',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'<gpx([^>]*)\s+xmlns:[^=]*="[^"]*"', caseSensitive: false),
      r'<gpx$1',
    );
    
    // Add back the standard namespace
    if (!cleaned.contains('xmlns=')) {
      cleaned = cleaned.replaceFirst(
        RegExp(r'<gpx([^>]*)>', caseSensitive: false),
        r'<gpx$1 xmlns="http://www.topografix.com/GPX/1/1">',
      );
    }
    
    // Normalize the gpx tag to ensure it's properly formatted
    if (!cleaned.contains('<gpx')) {
      // If no gpx tag found, this might not be a valid GPX file
      throw Exception('Invalid GPX file: no <gpx> root element found');
    }
    
    return cleaned;
  }
}
