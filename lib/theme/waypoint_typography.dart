// LEGACY SHIM — redirects to core typography.
// Do not add new styles here. Use lib/core/theme/typography.dart.
import 'package:waypoint/core/theme/typography.dart' as core;
import 'package:waypoint/core/theme/colors.dart';
import 'package:flutter/material.dart';

/// Legacy class name for backward compatibility
/// Maps old names to the equivalent core style
class WaypointTypography {
  // adventure_detail_screen uses these names
  static TextStyle get displayMedium  => core.WaypointTypography.displayLargeSerif;
  static TextStyle get bodyLarge      => core.WaypointTypography.body;
  static TextStyle get bodyMedium     => core.WaypointTypography.bodySmall;
  static TextStyle get chipLabel      => core.WaypointTypography.tiny;
  static TextStyle get tabLabel       => core.WaypointTypography.tabLabel;
  static TextStyle get tabActive      => core.WaypointTypography.tabActive;
  static TextStyle get tabDayLabel    => core.WaypointTypography.tabLabel;
  static TextStyle get tabDayActive   => core.WaypointTypography.tabActive;
  static TextStyle get displayLarge    => core.WaypointTypography.display;
  static TextStyle get headlineMedium => core.WaypointTypography.headline;
  static TextStyle get headlineSmall  => core.WaypointTypography.titleSmall;
  static TextStyle get titleMedium    => core.WaypointTypography.title;
  static TextStyle get bodySmall      => core.WaypointTypography.bodySmall;
  
  // Stat styles (from old waypoint_typography.dart)
  static TextStyle get statValue => TextStyle(
    fontFamily: 'DMSans',
    fontSize: 24.0,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: NeutralColors.textPrimary,
  );
  
  static TextStyle get statLabel => TextStyle(
    fontFamily: 'DMSans',
    fontSize: 10.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: NeutralColors.textSecondary,
  );
}
