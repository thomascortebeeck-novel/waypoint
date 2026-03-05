import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class WaypointPinGeometry {
  WaypointPinGeometry._();

  static const double mapPinWidth  = 46.0;
  static const double mapPinHeight = 58.0;  // was 50 — extra 8px gives longer tip
  static const double badgeWidth   = 36.0;
  static const double badgeHeight  = 40.0;

  // ── Circle ────────────────────────────────────────────────────────────────
  // Absolute position kept identical to before (cy=18.5px, r=14.26px).
  // cy fraction adjusted from 0.37 to 0.319 because canvas is now taller.
  static Offset circleCenter(double w, double h) => Offset(w / 2, h * 0.319);
  static double circleRadius(double w) => w * 0.31;

  static Path buildPlectrumPath(double w, double h) {
    final cx      = w / 2;
    final cornerY = h * 0.142;
    final bowCPy  = -cornerY;
    final tipY    = h * 0.995;
    final cr      = w * 0.07;   // corner rounding offset ≈ 3.2px

    // ── Tangent unit vectors ───────────────────────────────────────────────
    final inLen  = math.sqrt((w - cx) * (w - cx) + (cornerY - bowCPy) * (cornerY - bowCPy));
    final inDx   = (w - cx) / inLen;
    final inDy   = (cornerY - bowCPy) / inLen;

    final outLen = math.sqrt((w * 0.05) * (w * 0.05) + (h * 0.50 - cornerY) * (h * 0.50 - cornerY));
    final outDx  = -w * 0.05 / outLen;
    final outDy  = (h * 0.50 - cornerY) / outLen;

    final tipLen = math.sqrt((cx - w * 0.95) * (cx - w * 0.95) + (tipY - h * 0.50) * (tipY - h * 0.50));
    final tipDx  = (cx - w * 0.95) / tipLen;
    final tipDy  = (tipY - h * 0.50) / tipLen;

    // ── Corner rounding points ─────────────────────────────────────────────
    final rPre  = Offset(w - cr * inDx,  cornerY - cr * inDy);
    final rPost = Offset(w + cr * outDx, cornerY + cr * outDy);
    final lPre  = Offset(w - rPost.dx, rPost.dy);
    final lPost = Offset(w - rPre.dx,  rPre.dy);
    final tPre  = Offset(cx - cr * tipDx, tipY - cr * tipDy);
    final tPost = Offset(cx + cr * tipDx, tipY - cr * tipDy);

    final path = Path();
    path.moveTo(lPost.dx, lPost.dy);
    path.quadraticBezierTo(cx, bowCPy, rPre.dx, rPre.dy);       // bow
    path.quadraticBezierTo(w, cornerY, rPost.dx, rPost.dy);      // round right corner
    path.quadraticBezierTo(w * 0.95, h * 0.50, tPre.dx, tPre.dy); // right side
    path.quadraticBezierTo(cx, tipY, tPost.dx, tPost.dy);        // round tip
    path.quadraticBezierTo(w * 0.05, h * 0.50, lPre.dx, lPre.dy); // left side
    path.quadraticBezierTo(0, cornerY, lPost.dx, lPost.dy);      // round left corner
    path.close();
    return path;
  }

  static Path buildPlectrumPathForRing(double w, double h, {double pad = 3.0}) {
    final larger = buildPlectrumPath(w + pad * 2, h + pad * 2);
    return larger.transform(Matrix4.translationValues(-pad, -pad, 0).storage);
  }

  static void drawPlectrumBody(Canvas canvas, double w, double h, Paint paint) {
    canvas.drawPath(buildPlectrumPath(w, h), paint);
  }

  static void drawContentCircle(Canvas canvas, double w, double h, Paint paint) {
    canvas.drawCircle(circleCenter(w, h), circleRadius(w), paint);
  }
}
