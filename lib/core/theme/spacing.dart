import 'package:flutter/material.dart';

/// Waypoint Design System - Spacing Tokens
/// 
/// Base unit: 4px - All spacing should be multiples of 4

class WaypointSpacing {
  // ========================================
  // SPACING SCALE
  // ========================================
  static const double xs = 4.0;     // Tight spacing, icon gaps
  static const double sm = 8.0;     // Small gaps, chip padding
  static const double md = 16.0;    // Default spacing, card padding
  static const double lg = 24.0;    // Section spacing, large gaps
  static const double xl = 32.0;    // Page padding, major sections
  static const double xxl = 48.0;   // Hero sections, large separations
  static const double xxxl = 64.0;  // Extra large spacing

  // ========================================
  // EDGE INSETS - ALL SIDES
  // ========================================
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  // ========================================
  // EDGE INSETS - HORIZONTAL
  // ========================================
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // ========================================
  // EDGE INSETS - VERTICAL
  // ========================================
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  // ========================================
  // COMPONENT-SPECIFIC SPACING
  // ========================================
  
  /// Button padding (standard) - 12px vertical, 24px horizontal
  static const EdgeInsets buttonStandard = EdgeInsets.symmetric(horizontal: lg, vertical: 12);
  
  /// Button padding (small) - 8px vertical, 16px horizontal
  static const EdgeInsets buttonSmall = EdgeInsets.symmetric(horizontal: md, vertical: sm);
  
  /// Button padding (large) - 16px vertical, 32px horizontal
  static const EdgeInsets buttonLarge = EdgeInsets.symmetric(horizontal: xl, vertical: md);
  
  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20);
  
  /// Input padding - 14px vertical, 16px horizontal
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: md, vertical: 14);
  
  /// Chip padding - 6px vertical, 12px horizontal
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  
  /// Dialog padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(lg);
  
  /// Page padding (horizontal for mobile)
  static const EdgeInsets pagePaddingMobile = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pagePaddingTablet = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pagePaddingDesktop = EdgeInsets.symmetric(horizontal: xl);

  // ========================================
  // GAP SIZES FOR ROW/COLUMN
  // ========================================
  static const double gapXs = xs;
  static const double gapSm = sm;
  static const double gapMd = md;
  static const double gapLg = lg;
  static const double gapXl = xl;
}
