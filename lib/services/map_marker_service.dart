import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_geometry.dart';
import 'package:waypoint/components/waypoint/waypoint_timeline_config.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/models/route_waypoint.dart';

class MapMarkerService {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Returns a BitmapDescriptor for the plectrum pin (46×58 logical px at scale 1.0).
  /// Uses [getCategoryConfig] for color and icon; [devicePixelRatio] for crisp raster.
  /// [displayScale] scales the logical size (e.g. for responsive markers on Google Maps); default 1.0.
  /// Anchor is bottom tip (0.5, 1.0) — set on Marker.
  static Future<BitmapDescriptor> markerForType(
    String waypointType, {
    double devicePixelRatio = 2.0,
    bool isSelected = false,
    int? orderNumber,
    double displayScale = 1.0,
  }) async {
    final cacheKey =
        '$waypointType-$devicePixelRatio-$isSelected-$orderNumber-$displayScale';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final wt = _waypointTypeFromString(waypointType);
    final config = getCategoryConfig(wt);
    final bytes = await _paintMarker(
      fillColor: config.color,
      devicePixelRatio: devicePixelRatio,
      isSelected: isSelected,
      icon: config.icon,
      label: orderNumber?.toString(),
      displayScale: displayScale,
    );
    final descriptor = BitmapDescriptor.bytes(bytes);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  static void clearCache() => _cache.clear();

  /// Returns PNG bytes for the plectrum pin (e.g. for Mapbox web).
  /// Generate at devicePixelRatio × logical size; display at 46×58 logical.
  static Future<Uint8List> getMarkerImageBytes(
    String waypointType, {
    double devicePixelRatio = 2.0,
    bool isSelected = false,
  }) async {
    final wt = _waypointTypeFromString(waypointType);
    final config = getCategoryConfig(wt);
    return _paintMarker(
      fillColor: config.color,
      devicePixelRatio: devicePixelRatio,
      isSelected: isSelected,
      icon: config.icon,
      label: null,
    );
  }

  static WaypointType _waypointTypeFromString(String type) {
    final lower = type.toLowerCase();
    if (lower == 'activity') return WaypointType.attraction;
    if (lower == 'servicepoint') return WaypointType.service;
    return WaypointType.values.firstWhere(
      (e) => e.name.toLowerCase() == lower,
      orElse: () => WaypointType.attraction,
    );
  }

  static Future<Uint8List> _paintMarker({
    required Color fillColor,
    required double devicePixelRatio,
    bool isSelected = false,
    required IconData icon,
    String? label,
    double displayScale = 1.0,
  }) async {
    final scale = devicePixelRatio;
    // Logical dimensions (base 46×58, scaled by displayScale for responsive markers)
    final w = WaypointPinGeometry.mapPinWidth * displayScale;
    final h = WaypointPinGeometry.mapPinHeight * displayScale;
    // Physical pixel dimensions
    final pw = w * scale;
    final ph = h * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, pw, ph));
    final paint = Paint()..isAntiAlias = true;

    // Scale canvas: draw in logical coords, output at physical resolution
    canvas.scale(scale);

    // 1. Selected ring: larger path filled white, drawn BEFORE body
    if (isSelected) {
      paint.color = Colors.white;
      final ringPath = WaypointPinGeometry.buildPlectrumPathForRing(w, h);
      canvas.drawPath(ringPath, paint);
    }

    // 2. Plectrum body (category color)
    paint.color = fillColor;
    WaypointPinGeometry.drawPlectrumBody(canvas, w, h, paint);

    // 3. White content circle — ALWAYS drawCircle, never drawOval
    paint.color = Colors.white;
    WaypointPinGeometry.drawContentCircle(canvas, w, h, paint);

    // 4. Content: icon or number in the circle (category color on white)
    final center = WaypointPinGeometry.circleCenter(w, h);
    final radius = WaypointPinGeometry.circleRadius(w);
    final textColor = fillColor;

    if (label != null) {
      _paintNumber(canvas, center, radius, label, textColor);
    } else {
      _paintIcon(canvas, center, radius, icon, textColor);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(pw.round(), ph.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _paintIcon(
    Canvas canvas,
    Offset center,
    double radius,
    IconData iconData,
    Color color,
  ) {
    // Icon slightly larger than circle (1.2× radius) for presence; min 8pt so at 2x DPR it stays crisp (no pixelation).
    final fontSize = (radius * 1.2).clamp(8.0, 26.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: iconData.fontFamily ?? 'MaterialIcons',
          fontFamilyFallback: iconData.fontFamilyFallback,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  static void _paintNumber(
    Canvas canvas,
    Offset center,
    double radius,
    String label,
    Color color,
  ) {
    // Number slightly larger than circle (1.2× radius); min 8pt for crisp rendering at high DPR.
    final fontSize = (radius * 1.2).clamp(8.0, 20.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }
}
