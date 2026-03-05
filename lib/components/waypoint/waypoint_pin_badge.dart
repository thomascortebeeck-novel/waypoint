import 'package:flutter/material.dart';
import 'package:waypoint/components/waypoint/waypoint_pin_geometry.dart';

/// Plectrum pin badge with order number in the white circle, for waypoint lists.
///
/// Display value is [orderIndex] as-is. Callers should pass [waypoint.order] or
/// [index + 1] depending on whether the screen uses 0-based or 1-based order.
///
/// For orderIndex >= 10, shows up to two digits with reduced font (min 8px);
/// for 100+ shows "99+".
class WaypointPinBadge extends StatelessWidget {
  final int orderIndex;
  final Color color;
  final double width;
  final double height;

  const WaypointPinBadge({
    super.key,
    required this.orderIndex,
    required this.color,
    this.width = WaypointPinGeometry.badgeWidth,
    this.height = WaypointPinGeometry.badgeHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PinPainter(
          color: color,
          label: orderIndex > 99 ? '99+' : orderIndex.toString(),
          w: width,
          h: height,
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  final String label;
  final double w;
  final double h;

  const _PinPainter({
    required this.color,
    required this.label,
    required this.w,
    required this.h,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    // Body
    paint.color = color;
    WaypointPinGeometry.drawPlectrumBody(canvas, w, h, paint);

    // White circle — drawCircle only, never drawOval
    paint.color = Colors.white;
    WaypointPinGeometry.drawContentCircle(canvas, w, h, paint);

    // Number in circle (color = body color for contrast against white)
    final center = WaypointPinGeometry.circleCenter(w, h);
    final radius = WaypointPinGeometry.circleRadius(w);
    final fontSize = label.length > 1
        ? (radius * 1.1).clamp(8.0, 16.0)   // smaller for 2-digit numbers
        : (radius * 1.4).clamp(10.0, 20.0);  // larger for single digit

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,      // category color on white circle
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
  bool shouldRepaint(_PinPainter old) =>
      old.color != color || old.label != label;
}
