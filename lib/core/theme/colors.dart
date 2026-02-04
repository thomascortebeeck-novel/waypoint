import 'package:flutter/material.dart';

/// Waypoint Design System - Color Tokens
///
/// All colors are defined as tokens following the specification.
/// Use these tokens throughout the app for consistent theming.

// ========================================
// BRAND PALETTE
// ========================================
class BrandColors {
  static const Color primary = Color(0xFF2D6A4F);      // Lighter Green - Main brand color (CHANGED from Hunter Green)
  static const Color primaryDark = Color(0xFF0F261C);  // Darker shade of green
  static const Color primaryLight = Color(0xFF52B788); // Lighter green - Completed routes
  static const Color primaryContainerLight = Color(0xFF95F4C8); // Very light green for containers
  static const Color tertiaryDarkGreen = Color(0xFF1B4332); // Hunter Green - Moved from primary, used for tertiary elements
  static const Color secondary = Color(0xFFFCBF49);    // Maize Crayola - Accent/warnings (UNCHANGED)
  
  // Vibrant Green Palette (Promos & Badges)
  static const Color vibrantGreen = Color(0xFF10B981);
  static const Color vibrantGreenDark = Color(0xFF059669);
}

// ========================================
// ACCENT PALETTE
// ========================================
class AccentColors {
  static const Color yellow = Color(0xFFFCBF49);
  static const Color orange = Color(0xFFFCBF49); // Mapped to yellow/secondary for compatibility
  static const Color greenLight = Color(0xFF52B788);
  static const Color blueWater = Color(0xFF4A90A4);
}

// ========================================
// SEMANTIC COLORS
// ========================================
class SemanticColors {
  static const Color error = Color(0xFFD62828);          // Fire Engine Red
  static const Color success = Color(0xFF52B788);        // Medium Sea Green
  static const Color warning = Color(0xFFFCBF49);        // Same as accent - Warnings
  static const Color info = Color(0xFF4A90A4);           // Blue Munsell

  // Light variants for compatibility/backgrounds
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warningLight = Color(0xFFFFF3E0);
}

// ========================================
// NEUTRAL PALETTE
// ========================================
class NeutralColors {
  // New semantic names
  static const Color textPrimary = Color(0xFF212529);       // Charleston Green
  static const Color textSecondary = Color(0xFF495057);     // Davys Grey
  static const Color textOnPrimary = Color(0xFFFFFFFF);     // White
  
  static const Color backgroundPrimary = Color(0xFFF8F9FA); // Cultured
  static const Color backgroundSecondary = Color(0xFFE9ECEF); // Platinum
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Neutral Scale (Restored for compatibility)
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8F9FA); // Matches backgroundPrimary
  static const Color neutral100 = Color(0xFFF1F3F5);
  static const Color neutral200 = Color(0xFFE9ECEF); // Matches backgroundSecondary
  static const Color neutral300 = Color(0xFFDEE2E6);
  static const Color neutral400 = Color(0xFFCED4DA);
  static const Color neutral500 = Color(0xFFADB5BD);
  static const Color neutral600 = Color(0xFF6C757D);
  static const Color neutral700 = Color(0xFF495057); // Matches textSecondary
  static const Color neutral800 = Color(0xFF343A40);
  static const Color neutral900 = Color(0xFF212529); // Matches textPrimary
}

// ========================================
// STATUS COLORS
// ========================================
class StatusColors {
  /// Active/In-Progress states → Primary Green
  static const Color upcoming = BrandColors.primary;      // #2D6A4F - Upcoming trips
  static const Color published = BrandColors.primary;     // #2D6A4F - Published plans
  static const Color customizing = BrandColors.primary;   // #2D6A4F - Customizing trips
  static const Color inProgress = BrandColors.primary;    // #2D6A4F - In progress trips
  
  /// Draft/Warning states → Secondary Yellow
  static const Color draft = BrandColors.secondary;       // #FCBF49 - Draft plans/trips
  
  /// Completed/Neutral → Gray
  static const Color completed = Color(0xFF6C757D);        // Gray - Completed trips
  static const Color ready = SemanticColors.success;      // #52B788 - Ready state
  
  /// Background colors (light variants)
  static Color get upcomingBg => BrandColors.primary.withValues(alpha: 0.12);
  static Color get publishedBg => BrandColors.primary.withValues(alpha: 0.12);
  static Color get customizingBg => BrandColors.primary.withValues(alpha: 0.12);
  static Color get draftBg => BrandColors.secondary.withValues(alpha: 0.12);
  static Color get completedBg => Color(0xFF6C757D).withValues(alpha: 0.12);
  static Color get readyBg => SemanticColors.success.withValues(alpha: 0.12);
}

// ========================================
// DIFFICULTY COLORS
// ========================================
class DifficultyColors {
  static const Color easy = Color(0xFF52B788);    // Green
  static const Color moderate = Color(0xFFFCBF49); // Yellow/Orange  
  static const Color hard = Color(0xFFD62828);    // Red
}

// ========================================
// ACTIVITY TAG COLORS
// ========================================
class ActivityTagColors {
  /// Get color for activity category
  static Color getActivityColor(String activityLabel) {
    // Outdoor activities → Primary Green
    if (['Hiking', 'Skiing', 'Adventure', 'Cycling', 'Climbing', 'Road Tripping', 'Tours', 'City Trips'].contains(activityLabel)) {
      return BrandColors.primary;
    }
    // Comfort/Leisure → Secondary Yellow
    if (['Comfort'].contains(activityLabel)) {
      return BrandColors.secondary;
    }
    // Default → Primary Green
    return BrandColors.primary;
  }
  
  /// Get background color with opacity
  static Color getActivityBgColor(String activityLabel) {
    return getActivityColor(activityLabel).withValues(alpha: 0.12);
  }
}

// ========================================
// WAYPOINT ICON COLORS
// ========================================
class WaypointIconColors {
  /// Get icon color for waypoint type
  static Color getWaypointIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
      case 'restaurants':
        return SemanticColors.error; // #D62828 - Red for food/dining
      case 'accommodation':
      case 'accommodations':
      case 'activity':
      case 'activities':
      case 'waypoint':
      case 'waypoints':
      case 'viewingpoint':
      case 'viewing points':
        return BrandColors.primary; // #2D6A4F - Primary green
      default:
        return BrandColors.primary;
    }
  }
  
  /// Get background color with opacity for waypoint icons
  static Color getWaypointIconBgColor(String type) {
    return getWaypointIconColor(type).withValues(alpha: 0.12);
  }
}

// ========================================
// LIGHT MODE COLORS
// ========================================
class LightModeColors {
  // Brand
  static const Color primary = BrandColors.primary;
  static const Color primaryLight = BrandColors.primaryLight; // Restored
  static const Color onPrimary = NeutralColors.white;
  static const Color primaryContainer = BrandColors.primaryContainerLight; // Light container color
  static const Color onPrimaryContainer = Color(0xFF002114); // Dark text on light container

  // Secondary
  static const Color secondary = BrandColors.secondary;
  static const Color onSecondary = NeutralColors.textPrimary;
  static const Color secondaryContainer = Color(0xFFFFF3E0); // Lighter yellow/orange

  // Tertiary
  static const Color tertiary = BrandColors.tertiaryDarkGreen; // Old primary color
  static const Color onTertiary = NeutralColors.white;

  // Error
  static const Color error = SemanticColors.error;
  static const Color onError = NeutralColors.white;
  static const Color errorContainer = Color(0xFFFFEBEE);

  // Surface & Background
  static const Color surface = NeutralColors.white;
  static const Color surfaceContainer = NeutralColors.white; // Restored
  static const Color onSurface = NeutralColors.textPrimary;
  static const Color onSurfaceSecondary = NeutralColors.textSecondary;
  static const Color onSurfaceMuted = Color(0xFF6C757D);
  static const Color surfaceVariant = NeutralColors.backgroundSecondary;
  static const Color background = NeutralColors.backgroundPrimary;
  
  // Borders & Shadows
  static const Color outline = NeutralColors.backgroundSecondary;
  static const Color outlineVariant = Color(0xFFDEE2E6);
  static const Color shadow = NeutralColors.textPrimary; // Used with opacity

  // Semantic
  static const Color success = SemanticColors.success;
  static const Color warning = SemanticColors.warning;
  static const Color info = SemanticColors.info;
  
  // Aliases for compatibility
  static const Color backgroundSecondary = NeutralColors.backgroundSecondary;
}

// ========================================
// DARK MODE COLORS
// ========================================
class DarkModeColors {
  // Brand
  static const Color primary = Color(0xFF52B788); // Lighter green for dark mode
  static const Color primaryLight = Color(0xFF81C784); // Restored
  static const Color onPrimary = Color(0xFF0F261C);
  static const Color primaryContainer = BrandColors.tertiaryDarkGreen; // Use tertiary dark green
  static const Color onPrimaryContainer = Color(0xFFE8F5E9);

  // Secondary
  static const Color secondary = Color(0xFFFCBF49);
  static const Color onSecondary = Color(0xFF212529);
  static const Color secondaryContainer = Color(0xFF4A3B00);

  // Tertiary
  static const Color tertiary = Color(0xFF4A90A4);
  static const Color onTertiary = Color(0xFF001F25);

  // Error
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);

  // Surface & Background
  static const Color surface = Color(0xFF1C1C1C);
  static const Color surfaceContainer = Color(0xFF242424); // Restored
  static const Color onSurface = Color(0xFFE5E5E5);
  static const Color onSurfaceSecondary = Color(0xFFB0B0B0);
  static const Color onSurfaceMuted = Color(0xFF707070);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color background = Color(0xFF121212);

  // Borders & Shadows
  static const Color outline = Color(0xFF3A3A3A);
  static const Color outlineVariant = Color(0xFF2A2A2A);
  static const Color shadow = Color(0xFF000000);

  // Semantic
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFFCBF49);
  static const Color info = Color(0xFF4A90A4);
}

// ========================================
// GRADIENT DEFINITIONS
// ========================================
class WaypointGradients {
  static const LinearGradient brandPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.primary, BrandColors.primaryLight],
  );
  
  // Gradient using old primary for backward compatibility if needed
  static const LinearGradient brandPrimaryLegacy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.tertiaryDarkGreen, BrandColors.primary],
  );

  static LinearGradient heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.7),
    ],
  );
}

// ========================================
// BADGE COLORS
// ========================================
class BadgeColors {
  // Light mode
  static const lightBackground = NeutralColors.backgroundSecondary;
  static const lightText = NeutralColors.textSecondary;

  // Dark mode
  static const darkBackground = Color(0xFF374151);
  static const darkText = Color(0xFFE5E7EB);
}
