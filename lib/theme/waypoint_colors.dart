// LEGACY SHIM — redirects all existing imports to the core design system.
// Do not add new color definitions here. Use lib/core/theme/colors.dart.
export 'package:waypoint/core/theme/colors.dart';

import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Flat alias class — every field delegates to tokens (no local Color consts).
class WaypointColors {
  static const Color primary       = BrandingLightTokens.primary;
  static const Color onPrimary     = BrandingLightTokens.onPrimary;
  static const Color primaryLight  = LightModeColors.primaryLight;
  static const Color primarySurface = BrandingLightTokens.surface;

  static const Color accent        = BrandingLightTokens.accent;
  static const Color accentLight   = BrandingLightTokens.surface;

  static const Color surface       = BrandingLightTokens.surface;
  static const Color background    = BrandingLightTokens.background;
  static const Color border        = BrandingLightTokens.divider;
  static const Color borderLight   = BrandingLightTokens.surfaceVariant;

  static const Color textPrimary   = BrandingLightTokens.primaryText;
  static const Color textSecondary = BrandingLightTokens.secondaryText;
  static const Color textTertiary  = BrandingLightTokens.hint;

  /// Emphasis (e.g. ratings) — use brand primary in 4-color palette.
  static const Color gold          = BrandingLightTokens.primary;

  // POI section — semantic types (delegate to existing tokens)
  static const Color catStay = BrandingLightTokens.primary;
  static const Color catEat  = SemanticColors.error;
  static const Color catDo   = BrandColors.secondary;
  static const Color catFix  = NeutralColors.neutral600;

  static const Color catStaySurface = LightModeColors.primaryContainer;
  static const Color catEatSurface  = SemanticColors.errorLight;
  static const Color catDoSurface   = LightModeColors.secondaryContainer;
  static const Color catFixSurface  = BrandingLightTokens.surfaceVariant;

  static const Color catStayBorder = BrandingLightTokens.divider;
  static const Color catEatBorder  = BrandingLightTokens.divider;
  static const Color catDoBorder   = BrandingLightTokens.divider;
  static const Color catFixBorder  = BrandingLightTokens.divider;
}
