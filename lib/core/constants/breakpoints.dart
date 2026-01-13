/// Waypoint Design System - Responsive Breakpoints

class WaypointBreakpoints {
  // ========================================
  // BREAKPOINT DEFINITIONS
  // ========================================
  
  /// Mobile phones - < 600px
  static const double mobile = 600;
  
  /// Tablets - 600px - 1023px
  static const double tablet = 1024;
  
  /// Laptops, small desktops - 1024px - 1439px
  static const double desktop = 1440;
  
  /// Large desktops - >= 1440px
  static const double wide = 1440;

  // ========================================
  // CONTENT MAX WIDTHS
  // ========================================
  static const double contentMaxWidth = 1200;
  static const double dialogSmall = 400;
  static const double dialogMedium = 520;
  static const double dialogLarge = 640;
  static const double sidebarWidth = 240;

  // ========================================
  // GRID SYSTEM
  // ========================================
  
  /// Number of columns per breakpoint
  static int columnsFor(double width) {
    if (width < mobile) return 4;
    if (width < tablet) return 8;
    return 12;
  }

  /// Gutter size per breakpoint
  static double gutterFor(double width) {
    if (width < mobile) return 16;
    if (width < tablet) return 24;
    return 24;
  }

  /// Margin size per breakpoint
  static double marginFor(double width) {
    if (width < mobile) return 16;
    if (width < tablet) return 24;
    return 32;
  }

  // ========================================
  // HELPERS
  // ========================================
  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
  static bool isWide(double width) => width >= wide;
}
