import 'package:flutter/material.dart';
import '../theme/waypoint_spacing.dart';

/// Waypoint Adventure Detail Screen v3 - Responsive Breakpoints
/// 
/// Breakpoint definitions matching the v3 design specification.

class WaypointBreakpoints {
  // ========================================
  // BREAKPOINT VALUES
  // ========================================
  static const double mobile = 600.0;    // < 600px → mobile
  static const double tablet = 1024.0;   // 600-1024px → tablet
  static const double desktop = 1024.0;  // > 1024px → desktop
  // > 1024px → desktop
  
  // ========================================
  // CONTENT CONSTRAINTS
  // ========================================
  static const double contentMaxWidth = 1200.0;  // Max total width
  static const double contentWidth = 800.0;     // Main content width (desktop)
  static const double sidebarWidth = 320.0;      // Sidebar width (desktop)
  static const double tabletMaxWidth = 720.0;    // Tablet content max width
  
  // ========================================
  // HELPER METHODS
  // ========================================
  
  /// Check if current width is mobile
  static bool isMobile(double width) => width < mobile;
  
  /// Check if current width is tablet
  static bool isTablet(double width) => width >= mobile && width < tablet;
  
  /// Check if current width is desktop
  static bool isDesktop(double width) => width >= tablet;
  
  /// Get horizontal padding based on screen width
  static double getHorizontalPadding(double width) {
    if (isMobile(width)) {
      return WaypointSpacing.pagePaddingMobile;
    } else {
      return WaypointSpacing.pagePaddingDesktop;
    }
  }
  
  /// Get content max width based on screen width
  static double? getContentMaxWidth(double width) {
    if (isMobile(width)) {
      return null; // Full width on mobile
    } else if (isTablet(width)) {
      return tabletMaxWidth;
    } else {
      return contentMaxWidth;
    }
  }
}

