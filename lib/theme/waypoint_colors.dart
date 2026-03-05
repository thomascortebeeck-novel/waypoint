// LEGACY SHIM — redirects all existing imports to the core design system.
// Do not add new color definitions here. Use lib/core/theme/colors.dart.
export 'package:waypoint/core/theme/colors.dart';

import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Flat alias class used directly in adventure_detail_screen
/// and other screens that reference WaypointColors.xxx
class WaypointColors {
  // Primary — BRANDING_GUIDELINES
  static const Color primary       = BrandingLightTokens.primary;   // #228B22
  static const Color primaryLight  = Color(0xFF2E9D2E);
  static const Color primarySurface = BrandingLightTokens.surface;

  // Accent — orange from branding
  static const Color accent        = BrandingLightTokens.accent;   // #E67E22
  static const Color accentLight   = BrandingLightTokens.surface;

  // Surface & backgrounds — BRANDING_GUIDELINES
  static const Color surface       = BrandingLightTokens.surface;   // #F2E8CF
  static const Color background    = BrandingLightTokens.background; // #FDFBF7
  static const Color border        = BrandingLightTokens.divider;
  static const Color borderLight   = NeutralColors.neutral100;

  // Text
  static const Color textPrimary   = BrandingLightTokens.primaryText;
  static const Color textSecondary = BrandingLightTokens.secondaryText;
  static const Color textTertiary  = BrandingLightTokens.hint;

  // Special colors
  static const Color gold          = Color(0xFFD4A017); // Gold color

  // POI section tints — reference design (green=accommodation, red=restaurant, orange=activity, gray=service)
  static const Color catStay = Color(0xFF2D6A4F);   // Dark green — accommodation
  static const Color catEat  = Color(0xFFB5302A);    // Red — restaurant/bar
  static const Color catDo   = Color(0xFFE07B39);   // Orange — activity/attraction
  static const Color catFix  = Color(0xFF9E9E9E);   // Gray — gear/service

  // POI section surface colors (light backgrounds)
  static const Color catStaySurface = BrandColors.primaryContainerLight; // Pale green
  static const Color catEatSurface  = SemanticColors.errorLight;          // Light red
  static const Color catDoSurface   = BrandColors.secondaryContainer;    // Cream
  static const Color catFixSurface  = NeutralColors.neutral100;           // Light grey

  // POI section border colors
  static const Color catStayBorder = Color(0xFFC8E6C9); // Light green border
  static const Color catEatBorder  = Color(0xFFFFE0B2);  // Light orange border
  static const Color catDoBorder  = Color(0xFFFFE0B2); // Light yellow border
  static const Color catFixBorder = NeutralColors.neutral300; // Grey border
}
