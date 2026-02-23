import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:waypoint/core/theme/colors.dart';

class MapMarkerService {
  // Cache so we don't repaint the same marker twice
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Returns a colored BitmapDescriptor for [waypointType].
  /// Pass [devicePixelRatio] from MediaQuery to get crisp markers on all screens.
  static Future<BitmapDescriptor> markerForType(
    String waypointType, {
    double devicePixelRatio = 2.0,
    bool isSelected = false, // selected = larger ring around pin
    int? orderNumber, // optional number label inside pin
  }) async {
    final cacheKey =
        '$waypointType-$devicePixelRatio-$isSelected-$orderNumber';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final color = WaypointIconColors.markerColor(waypointType);
    final bytes = await _paintMarker(
      fillColor: color,
      borderColor: isSelected
          ? Colors.white
          : color.withValues(alpha: 0.85),
      devicePixelRatio: devicePixelRatio,
      isSelected: isSelected,
      waypointType: waypointType,
      label: orderNumber?.toString(),
    );
    final descriptor = BitmapDescriptor.bytes(bytes);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  // ---- Clear cache on hot reload (dev only) ----
  static void clearCache() => _cache.clear();

  // ---- Core painter ----
  static Future<Uint8List> _paintMarker({
    required Color fillColor,
    required Color borderColor,
    required double devicePixelRatio,
    bool isSelected = false,
    required String waypointType,
    String? label,
  }) async {
    // Logical pin dimensions
    const double pinWidth = 32.0;
    const double pinHeight = 44.0;
    const double bodyRadius = pinWidth / 2;

    // Scale for device pixel ratio
    final double scale = devicePixelRatio;
    final double w = pinWidth * scale;
    final double h = pinHeight * scale;
    final double r = bodyRadius * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    final paint = Paint()..isAntiAlias = true;

    // ---- Shadow ----
    paint
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(w / 2, r + 2 * scale), r, paint);
    paint.maskFilter = null;

    // ---- Selection ring (white outline if selected) ----
    if (isSelected) {
      paint.color = Colors.white;
      canvas.drawCircle(Offset(w / 2, r), r + 3 * scale, paint);
    }

    // ---- Pin circle (body) ----
    paint.color = fillColor;
    canvas.drawCircle(Offset(w / 2, r), r, paint);

    // ---- Pin tail (downward triangle) ----
    final tailPath = Path()
      ..moveTo(w / 2 - 6 * scale, r + r * 0.6)
      ..lineTo(w / 2 + 6 * scale, r + r * 0.6)
      ..lineTo(w / 2, h - 4 * scale)
      ..close();
    paint.color = fillColor;
    canvas.drawPath(tailPath, paint);

    // ---- Inner white circle (to create donut look for contrast) ----
    paint.color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(w / 2, r), r * 0.55, paint);

    // ---- Icon or number label ----
    if (label != null) {
      // Show order number
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w800,
            color: _labelColor(fillColor),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          w / 2 - textPainter.width / 2,
          r - textPainter.height / 2,
        ),
      );
    } else {
      // Show icon
      final iconCodepoint =
          WaypointIconColors.markerIconCodepoint(waypointType);
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconCodepoint),
          style: TextStyle(
            fontSize: 16 * scale,
            fontFamily: 'MaterialIcons',
            color: _labelColor(fillColor),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          w / 2 - textPainter.width / 2,
          r - textPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // White label on dark pins, dark label on bright pins (Maize Yellow)
  static Color _labelColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.35 ? const Color(0xFF212529) : Colors.white;
  }
}

