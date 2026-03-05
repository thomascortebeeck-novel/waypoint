import 'package:flutter/material.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_geometry.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Paints the plectrum/shield waypoint pin with white circle cutout.
/// Used by [WaypointPinBadge] (number mode) and by Flutter Map marker (icon mode).
/// Geometry follows [WaypointPinGeometry]; content in circle is either icon or number.
class WaypointPinPainter extends CustomPainter {
  final Color bodyColor;
  final bool showSelectedRing;
  final IconData? icon;
  final int? orderIndex;
  final double width;
  final double height;

  /// Luminance threshold: white text when body luminance < 0.4, dark when >= 0.4.
  static const double kLuminanceThreshold = 0.4;

  WaypointPinPainter({
    required this.bodyColor,
    this.showSelectedRing = false,
    this.icon,
    this.orderIndex,
    required this.width,
    required this.height,
  }) : assert(icon != null || orderIndex != null, 'Provide either icon or orderIndex');

  @override
  void paint(Canvas canvas, Size size) {
    final w = width;
    final h = height;
    final paint = Paint()..isAntiAlias = true;

    // 1. Selected ring: second path scaled up, filled white, before body
    if (showSelectedRing) {
      paint.color = Colors.white;
      final ringPath = WaypointPinGeometry.buildPlectrumPathForRing(w, h);
      canvas.drawPath(ringPath, paint);
    }

    // 2. Plectrum body
    paint.color = bodyColor;
    WaypointPinGeometry.drawPlectrumBody(canvas, w, h, paint);

    // 3. White content circle (drawCircle only)
    paint.color = Colors.white;
    WaypointPinGeometry.drawContentCircle(canvas, w, h, paint);

    // 4. Content: icon or number
    final center = WaypointPinGeometry.circleCenter(w, h);
    final radius = WaypointPinGeometry.circleRadius(w);
    final textColor = bodyColor.computeLuminance() < kLuminanceThreshold
        ? Colors.white
        : BrandingLightTokens.formLabel;

    if (icon != null) {
      _paintIcon(canvas, center, radius, icon!, textColor);
    } else {
      _paintNumber(canvas, center, radius, orderIndex!, textColor);
    }
  }

  void _paintIcon(Canvas canvas, Offset center, double radius, IconData iconData, Color color) {
    const iconSize = 20.0; // logical; scale by size if needed
    final scale = (radius * 2 * 0.7) / iconSize;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: iconSize * scale,
          fontFamily: iconData.fontFamily,
          fontFamilyFallback: iconData.fontFamilyFallback,
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

  void _paintNumber(Canvas canvas, Offset center, double radius, int index, Color color) {
    final String text = index >= 100 ? '99+' : index.toString(); // max 2 digits or "99+"
    final fontSize = radius * 1.4;
    final minFontSize = 8.0;
    final effectiveSize = fontSize.clamp(minFontSize, radius * 1.6);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: effectiveSize,
          fontWeight: FontWeight.w700,
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

  @override
  bool shouldRepaint(WaypointPinPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.showSelectedRing != showSelectedRing ||
        oldDelegate.icon != icon ||
        oldDelegate.orderIndex != orderIndex ||
        oldDelegate.width != width ||
        oldDelegate.height != height;
  }
}
