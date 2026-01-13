import 'package:flutter/material.dart';

/// Waypoint Design System - Border Radius Tokens

class WaypointRadius {
  // ========================================
  // RADIUS SCALE
  // ========================================
  static const double xs = 4.0;      // Tiny elements
  static const double sm = 8.0;      // Chips, badges, small buttons
  static const double md = 12.0;     // Buttons, inputs, small cards
  static const double lg = 16.0;     // Cards, dialogs
  static const double xl = 24.0;     // Large dialogs, bottom sheets
  static const double full = 9999.0; // Pills, circular buttons

  // ========================================
  // BORDER RADIUS
  // ========================================
  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderFull = BorderRadius.all(Radius.circular(full));

  // ========================================
  // TOP ONLY RADIUS (for bottom sheets)
  // ========================================
  static const BorderRadius topXl = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );

  // ========================================
  // BORDER WIDTHS
  // ========================================
  static const double borderThin = 1.0;    // Default borders
  static const double borderMedium = 1.5;  // Input focus, selected states
  static const double borderThick = 2.0;   // Strong emphasis, active states
}
