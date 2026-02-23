// LEGACY SHIM — redirects all existing imports to the core design system.
// Do not add new color definitions here. Use lib/core/theme/colors.dart.
export 'package:waypoint/core/theme/colors.dart';

import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Flat alias class used directly in adventure_detail_screen
/// and other screens that reference WaypointColors.xxx
class WaypointColors {
  // Primary
  static const Color primary       = BrandColors.primary;       // #1B4332
  static const Color primaryLight  = BrandColors.primaryLight;  // #2D6A4F
  static const Color primarySurface = BrandColors.primaryContainerLight; // Pale green

  // Accent
  static const Color accent        = BrandColors.secondary;     // #FCBF49
  static const Color accentLight   = BrandColors.secondaryContainer; // Cream

  // Surface & backgrounds
  static const Color surface       = NeutralColors.white;
  static const Color background    = NeutralColors.backgroundPrimary; // #F8F9FA
  static const Color border        = NeutralColors.backgroundSecondary; // #E9ECEF
  static const Color borderLight   = NeutralColors.neutral100;

  // Text
  static const Color textPrimary   = NeutralColors.textPrimary;   // #212529
  static const Color textSecondary = NeutralColors.textSecondary; // #495057
  static const Color textTertiary  = NeutralColors.neutral600;    // #6C757D

  // Special colors
  static const Color gold          = Color(0xFFD4A017); // Gold color

  // POI section tints
  static const Color catStay = BrandColors.primary;               // Hunter Green
  static const Color catEat  = SemanticColors.error;             // #D62828
  static const Color catDo   = BrandColors.secondary;            // #FCBF49
  static const Color catFix  = NeutralColors.neutral600;         // grey

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
