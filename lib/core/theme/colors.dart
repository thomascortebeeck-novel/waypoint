import 'package:flutter/material.dart';

// ============================================================
// WAYPOINT BRAND PALETTE
// Source: Waypoint Brand Guidelines + BRANDING_GUIDELINES.md
// ============================================================
/// Canonical light theme tokens — 4-color palette: fdfbf7, faf5eb, f2e8d0, 2f7d32.
class BrandingLightTokens {
  static const Color primary        = Color(0xFF2F7D32); // Brand green - logo, CTAs, selected
  static const Color onPrimary      = Color(0xFFFFFFFF);
  static const Color secondary      = Color(0xFF5D3A1A); // Dark brown - secondary text only
  static const Color onSecondary    = Color(0xFFFFFFFF);
  static const Color background     = Color(0xFFFDFBF7); // Page background
  static const Color surface        = Color(0xFFFAF5EB); // Sidebar, cards, sections
  static const Color surfaceVariant = Color(0xFFF2E8D0); // Elevated surfaces, subtle dividers
  static const Color onSurface      = Color(0xFF212529); // Primary text
  static const Color error          = Color(0xFFD62828);
  static const Color onError        = Color(0xFFFFFFFF);
  static const Color accent         = Color(0xFF2F7D32); // Aligned to primary for light mode
  static const Color divider        = Color(0xFFF2E8D0); // Very subtle
  static const Color hint           = Color(0xFFA8A29E);
  static const Color primaryText    = Color(0xFF212529);
  static const Color secondaryText  = Color(0xFF5D3A1A);
  static const Color success        = Color(0xFF386641);
  /// Form / waypoint edit: input and pill background
  static const Color formFieldBackground = Color(0xFFFAF5EB);
  /// Form / waypoint edit: input and pill border
  static const Color formFieldBorder = Color(0xFFF2E8D0);
  /// App bar, Save button, selected chip
  static const Color appBarGreen = Color(0xFF2F7D32);
  /// Form labels and section titles
  static const Color formLabel = Color(0xFF1A1D21);
}

/// Light theme shadow/elevation — single source of truth (minimal, no heavy shadows).
const double kLightCardElevation = 0.0;
const Color kLightShadowColor = Colors.transparent;

class BrandColors {
  // --- Primary (Hunter Green) ---
  static const Color primary            = Color(0xFF1B4332); // Hunter Green
  static const Color primaryDark        = Color(0xFF0F261C); // Deeper shade
  static const Color primaryLight       = Color(0xFF2D6A4F); // Forest Green - hover/completed
  static const Color primaryContainerLight = Color(0xFFD8F3DC); // Pale green container

  // Legacy alias kept for backwards compatibility
  static const Color tertiaryDarkGreen  = Color(0xFF1B4332);

  // --- Secondary (Maize Crayola) ---
  static const Color secondary          = Color(0xFFFCBF49); // Maize Crayola
  static const Color secondaryDark      = Color(0xFFE6A82E); // Darker amber
  static const Color secondaryLight     = Color(0xFFFFD97D); // Lighter amber
  static const Color secondaryContainer = Color(0xFFFFF3DC); // Cream

  // --- Success (Medium Sea Green) ---
  static const Color successGreen       = Color(0xFF52B788); // Easy trails, success
  static const Color successContainer   = Color(0xFFD8F3DC); // Light success bg

  // --- Vibrant (promos, badges) ---
  static const Color vibrantGreen       = Color(0xFF10B981);
  static const Color vibrantGreenDark   = Color(0xFF059669);
}

// ============================================================
// ACCENT PALETTE
// Legacy compatibility - use BrandColors.secondary instead
// ============================================================
class AccentColors {
  static const Color yellow = Color(0xFFFCBF49);
  static const Color orange = Color(0xFFFCBF49); // Mapped to yellow/secondary for compatibility
  static const Color greenLight = Color(0xFF52B788);
  static const Color blueWater = Color(0xFF4A90A4);
}

// ============================================================
// NEUTRAL PALETTE
// Source: Waypoint Brand Guidelines
// ============================================================
class NeutralColors {
  // Semantic names (primary usage)
  static const Color textPrimary        = Color(0xFF212529); // Charleston Green
  static const Color textSecondary      = Color(0xFF495057); // Davys Grey
  static const Color textOnPrimary      = Color(0xFFFFFFFF); // White on dark
  static const Color backgroundPrimary  = Color(0xFFF8F9FA); // Cultured
  static const Color backgroundSecondary = Color(0xFFE9ECEF); // Platinum
  static const Color white              = Color(0xFFFFFFFF);
  static const Color black              = Color(0xFF000000);

  // Numeric scale — used internally by theme components
  static const Color neutral0   = Color(0xFFFFFFFF);
  static const Color neutral50  = Color(0xFFF8F9FA); // = backgroundPrimary
  static const Color neutral100 = Color(0xFFF1F3F5);
  static const Color neutral200 = Color(0xFFE9ECEF); // = backgroundSecondary
  static const Color neutral300 = Color(0xFFDEE2E6);
  static const Color neutral400 = Color(0xFFCED4DA);
  static const Color neutral500 = Color(0xFFADB5BD);
  static const Color neutral600 = Color(0xFF6C757D);
  static const Color neutral700 = Color(0xFF495057); // = textSecondary
  static const Color neutral800 = Color(0xFF343A40);
  static const Color neutral900 = Color(0xFF212529); // = textPrimary
}

// ============================================================
// SEMANTIC COLORS
// ============================================================
class SemanticColors {
  static const Color error        = Color(0xFFD62828); // Fire Engine Red
  static const Color success      = Color(0xFF52B788); // Medium Sea Green
  static const Color warning      = Color(0xFFFCBF49); // Maize Crayola
  static const Color info         = Color(0xFF4A90A4); // Blue Munsell

  static const Color errorLight   = Color(0xFFFFEBEE);
  static const Color successLight = Color(0xFFD8F3DC);
  static const Color warningLight = Color(0xFFFFF3DC);
  static const Color infoLight    = Color(0xFFE3F2FD);
}

// ============================================================
// LIGHT MODE TOKEN MAP
// 4-color palette: fdfbf7, faf5eb, f2e8d0, 2f7d32
// ============================================================
class LightModeColors {
  // Brand
  static const Color primary              = BrandingLightTokens.primary;     // #2F7D32
  static const Color primaryLight         = Color(0xFF3D8F40);
  static const Color onPrimary            = BrandingLightTokens.onPrimary;
  static const Color primaryContainer     = BrandingLightTokens.surfaceVariant; // f2e8d0
  static const Color onPrimaryContainer   = BrandingLightTokens.primaryText;

  // Secondary — text only
  static const Color secondary            = BrandingLightTokens.secondary;
  static const Color onSecondary          = BrandingLightTokens.onSecondary;
  static const Color secondaryContainer   = BrandingLightTokens.surfaceVariant;

  // Tertiary — aligned to primary for minimal palette
  static const Color tertiary             = BrandingLightTokens.primary;
  static const Color onTertiary           = NeutralColors.white;
  static const Color tertiaryContainer   = BrandingLightTokens.surfaceVariant;
  static const Color onTertiaryContainer  = BrandingLightTokens.primary;

  // Error
  static const Color error                = BrandingLightTokens.error;
  static const Color onError              = BrandingLightTokens.onError;
  static const Color errorContainer       = SemanticColors.errorLight;

  // Surface & Background — only fdfbf7, faf5eb, f2e8d0
  static const Color surface              = BrandingLightTokens.surface;       // faf5eb
  static const Color surfaceContainer     = BrandingLightTokens.surfaceVariant; // f2e8d0
  static const Color surfaceContainerLow  = BrandingLightTokens.surface;       // faf5eb
  static const Color surfaceContainerHigh = BrandingLightTokens.surfaceVariant;
  static const Color surfaceContainerHighest = BrandingLightTokens.surfaceVariant;
  static const Color onSurface            = BrandingLightTokens.onSurface;
  static const Color onSurfaceSecondary   = BrandingLightTokens.secondaryText;
  static const Color onSurfaceMuted       = BrandingLightTokens.hint;
  static const Color surfaceVariant       = BrandingLightTokens.surfaceVariant;
  static const Color background           = BrandingLightTokens.background;    // fdfbf7

  // Borders & Shadows
  static const Color outline              = BrandingLightTokens.divider;      // very subtle
  static const Color outlineVariant       = BrandingLightTokens.surfaceVariant;
  static const Color shadow               = kLightShadowColor;

  // Semantic aliases
  static const Color success              = BrandingLightTokens.success;
  static const Color warning              = BrandColors.secondary;
  static const Color info                 = SemanticColors.info;

  // Legacy alias
  static const Color backgroundSecondary  = BrandingLightTokens.surfaceVariant;
}

// ============================================================
// DARK MODE TOKEN MAP
// ============================================================
class DarkModeColors {
  static const Color primary              = BrandColors.successGreen;   // #52B788 lighter on dark
  static const Color primaryLight         = Color(0xFF81C784);
  static const Color onPrimary            = BrandColors.primaryDark;
  static const Color primaryContainer     = BrandColors.primary;
  static const Color onPrimaryContainer   = Color(0xFFE8F5E9);

  static const Color secondary            = BrandColors.secondary;      // #FCBF49
  static const Color onSecondary          = NeutralColors.textPrimary;
  static const Color secondaryContainer   = Color(0xFF4A3B00);

  static const Color tertiary             = SemanticColors.info;        // #4A90A4
  static const Color onTertiary           = Color(0xFF001F25);

  static const Color error                = Color(0xFFFFB4AB);
  static const Color onError              = Color(0xFF690005);

  static const Color surface              = Color(0xFF1C1C1C);
  static const Color surfaceContainer     = Color(0xFF242424);
  static const Color onSurface           = Color(0xFFE5E5E5);
  static const Color onSurfaceSecondary   = Color(0xFFB0B0B0);
  static const Color onSurfaceMuted       = Color(0xFF707070);
  static const Color surfaceVariant       = Color(0xFF2A2A2A);
  static const Color background           = Color(0xFF121212);

  static const Color outline              = Color(0xFF3A3A3A);
  static const Color outlineVariant       = Color(0xFF2A2A2A);
  static const Color shadow               = NeutralColors.black;

  static const Color success              = BrandColors.successGreen;
  static const Color warning              = BrandColors.secondary;
  static const Color info                 = SemanticColors.info;
}

// ============================================================
// STATUS COLORS
// ============================================================
class StatusColors {
  static const Color upcoming    = BrandColors.primary;
  static const Color published   = BrandColors.primary;
  static const Color customizing = BrandColors.primary;
  static const Color inProgress  = BrandColors.primary;
  static const Color draft       = BrandColors.secondary;
  static const Color completed   = NeutralColors.neutral600;
  static const Color ready       = SemanticColors.success;

  static Color get upcomingBg    => BrandColors.primary.withValues(alpha: 0.12);
  static Color get publishedBg   => BrandColors.primary.withValues(alpha: 0.12);
  static Color get customizingBg => BrandColors.primary.withValues(alpha: 0.12);
  static Color get draftBg       => BrandColors.secondary.withValues(alpha: 0.12);
  static Color get completedBg   => NeutralColors.neutral600.withValues(alpha: 0.12);
  static Color get readyBg       => SemanticColors.success.withValues(alpha: 0.12);
}

// ============================================================
// DIFFICULTY COLORS
// ============================================================
class DifficultyColors {
  static const Color easy     = SemanticColors.success;   // #52B788
  static const Color moderate = BrandColors.secondary;    // #FCBF49
  static const Color hard     = SemanticColors.error;     // #D62828
}

// ============================================================
// ACTIVITY TAG COLORS
// ============================================================
class ActivityTagColors {
  static Color getActivityColor(String activityLabel) {
    if (['Hiking', 'Skiing', 'Adventure', 'Cycling',
         'Climbing', 'Road Tripping', 'Tours', 'City Trips']
        .contains(activityLabel)) {
      return BrandColors.primary;
    }
    if (['Comfort'].contains(activityLabel)) {
      return BrandColors.secondary;
    }
    return BrandColors.primary;
  }

  static Color getActivityBgColor(String activityLabel) =>
      getActivityColor(activityLabel).withValues(alpha: 0.12);
}

// ============================================================
// WAYPOINT ICON COLORS
// ============================================================
class WaypointIconColors {
  static Color getWaypointIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'restaurants':
        return SemanticColors.error;       // Red for food/dining
      case 'accommodation':
      case 'accommodations':
      case 'activity':
      case 'activities':
      case 'waypoint':
      case 'waypoints':
      case 'viewingpoint':
      case 'viewing points':
        return BrandColors.primary;        // Hunter Green
      default:
        return BrandColors.primary;
    }
  }

  static Color getWaypointIconBgColor(String type) =>
      getWaypointIconColor(type).withValues(alpha: 0.12);

  /// Returns marker fill color for waypoint type
  static Color markerColor(String type) {
    switch (type.toLowerCase()) {
      case 'accommodation':
      case 'accommodations':
      case 'stay':
        return BrandColors.primary;       // #1B4332 Hunter Green

      case 'restaurant':
      case 'restaurants':
      case 'bar':
      case 'bars':
      case 'eat':
        return SemanticColors.error;      // #D62828 Fire Engine Red

      case 'activity':
      case 'activities':
      case 'attraction':
      case 'attractions':
      case 'viewingpoint':
      case 'viewing points':
      case 'do':
        return BrandColors.secondary;     // #FCBF49 Maize Yellow

      case 'logistics':
      case 'service':
      case 'servicepoint':
      case 'move':
      case 'transport':
        return SemanticColors.info;       // #4A90A4 Blue Munsell

      case 'waypoint':                    // Generic route waypoint
      case 'waypoints':
      case 'routepoint':
        return BrandColors.primaryLight;  // #2D6A4F Forest Green

      default:
        return BrandColors.primary;
    }
  }

  /// Returns MaterialIcons codepoint for waypoint type
  /// Uses IconData.codePoint to read from loaded font at runtime (version-safe)
  /// Uses MaterialIcons font family for reliable Canvas rendering on web
  static int markerIconCodepoint(String type) {
    switch (type.toLowerCase()) {
      case 'accommodation':
      case 'accommodations':
      case 'stay':
        return Icons.hotel_outlined.codePoint;

      case 'restaurant':
      case 'restaurants':
      case 'eat':
        return Icons.restaurant_outlined.codePoint;

      case 'bar':
      case 'bars':
        return Icons.local_bar_outlined.codePoint;

      case 'activity':
      case 'activities':
      case 'attraction':
      case 'attractions':
      case 'do':
        return Icons.local_activity_outlined.codePoint; // ticket/star icon for activities

      case 'viewingpoint':
      case 'viewing points':
        return Icons.visibility_outlined.codePoint; // eye icon for viewpoints

      case 'logistics':
      case 'service':
      case 'servicepoint':
      case 'move':
      case 'transport':
        return Icons.directions_car_outlined.codePoint;

      case 'waypoint':                    // Generic route waypoint
      case 'waypoints':
      case 'routepoint':
        return Icons.place_outlined.codePoint;

      default:
        return Icons.place_outlined.codePoint;
    }
  }
}

// ============================================================
// GRADIENTS
// ============================================================
class WaypointGradients {
  static const LinearGradient brandPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.primary, BrandColors.primaryLight],
  );

  static const LinearGradient brandPrimaryLegacy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.primaryDark, BrandColors.primary],
  );

  // Hero image scrim — bottom-heavy for text legibility
  static LinearGradient heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.7),
    ],
  );
}

// ============================================================
// BADGE COLORS
// ============================================================
class BadgeColors {
  static const Color lightBackground = NeutralColors.backgroundSecondary;
  static const Color lightText       = NeutralColors.textSecondary;
  static const Color darkBackground  = Color(0xFF374151);
  static const Color darkText        = Color(0xFFE5E7EB);
}
