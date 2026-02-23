import 'package:flutter/material.dart';

/// Waypoint Adventure Detail Screen v3 - Spacing Tokens
/// 
/// Spacing constants matching the v3 design specification.

class WaypointSpacing {
  // ========================================
  // SECTION SPACING
  // ========================================
  static const double sectionGap = 32.0;      // Between major sections
  static const double subsectionGap = 16.0;   // Within sections
  static const double fieldGap = 12.0;        // Between form fields
  static const double gapSm = 8.0;            // Small gaps (between buttons, links)
  static const double gapXs = 4.0;            // Extra small gaps
  
  // ========================================
  // CARD SPACING
  // ========================================
  static const double cardGap = 10.0;         // Between cards in grid
  static const double cardPadding = 14.0;     // Inside cards
  static const double cardRadius = 12.0;      // Card border radius
  static const double cardRadiusLg = 16.0;    // Hero, map border radius
  
  // ========================================
  // PAGE PADDING
  // ========================================
  static const double pagePaddingMobile = 16.0;
  static const double pagePaddingDesktop = 24.0;
  
  // ========================================
  // EDGE INSETS HELPERS
  // ========================================
  static const EdgeInsets pagePaddingMobileInsets = EdgeInsets.symmetric(horizontal: pagePaddingMobile);
  static const EdgeInsets pagePaddingDesktopInsets = EdgeInsets.symmetric(horizontal: pagePaddingDesktop);
  static const EdgeInsets cardPaddingInsets = EdgeInsets.all(cardPadding);
}

