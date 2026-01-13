import 'package:flutter/material.dart';

/// Waypoint Design System - Color Tokens
/// 
/// All colors are defined as tokens following the specification.
/// Use these tokens throughout the app for consistent theming.

// ========================================
// BRAND PALETTE
// ========================================
class BrandColors {
  static const Color primary = Color(0xFF428A13);
  static const Color primaryDark = Color(0xFF2D5A27);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryMuted = Color(0xFFA5D6A7);
}

// ========================================
// ACCENT PALETTE
// ========================================
class AccentColors {
  static const Color orange = Color(0xFFE65100);
  static const Color orangeLight = Color(0xFFFFF3E0);
  static const Color blue = Color(0xFF1976D2);
  static const Color blueLight = Color(0xFFE3F2FD);
}

// ========================================
// SEMANTIC COLORS
// ========================================
class SemanticColors {
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
}

// ========================================
// NEUTRAL PALETTE
// ========================================
class NeutralColors {
  static const Color neutral900 = Color(0xFF1A1A1A);
  static const Color neutral700 = Color(0xFF424242);
  static const Color neutral600 = Color(0xFF5C5C5C);
  static const Color neutral500 = Color(0xFF8A8A8A);
  static const Color neutral400 = Color(0xFFABABAB);
  static const Color neutral300 = Color(0xFFD1D9D1);
  static const Color neutral200 = Color(0xFFE5EBE5);
  static const Color neutral100 = Color(0xFFF0F4F0);
  static const Color neutral50 = Color(0xFFFAFBFA);
  static const Color neutral0 = Color(0xFFFFFFFF);
}

// ========================================
// DIFFICULTY COLORS
// ========================================
class DifficultyColors {
  static const Color easy = Color(0xFF4CAF50);
  static const Color moderate = Color(0xFFFF9800);
  static const Color hard = Color(0xFFF44336);
  static const Color extreme = Color(0xFF212121);
}

// ========================================
// WAYPOINT TYPE COLORS
// ========================================
class WaypointTypeColors {
  static const Color restaurant = Color(0xFFE91E63);
  static const Color accommodation = Color(0xFF9C27B0);
  static const Color activity = Color(0xFF2196F3);
  static const Color viewpoint = Color(0xFF00BCD4);
  static const Color routePoint = Color(0xFF428A13);
}

// ========================================
// LIGHT MODE COLORS
// ========================================
class LightModeColors {
  // Brand
  static const Color primary = BrandColors.primary;
  static const Color primaryDark = BrandColors.primaryDark;
  static const Color primaryLight = BrandColors.primaryLight;
  static const Color onPrimary = NeutralColors.neutral0;
  static const Color primaryContainer = BrandColors.primaryLight;
  static const Color onPrimaryContainer = Color(0xFF0D2E00);

  // Secondary (Accent Orange)
  static const Color secondary = AccentColors.orange;
  static const Color onSecondary = NeutralColors.neutral0;
  static const Color secondaryContainer = AccentColors.orangeLight;

  // Tertiary (Info Blue)
  static const Color tertiary = AccentColors.blue;
  static const Color onTertiary = NeutralColors.neutral0;

  // Error
  static const Color error = SemanticColors.error;
  static const Color onError = NeutralColors.neutral0;
  static const Color errorContainer = SemanticColors.errorLight;

  // Surface & Background
  static const Color surface = NeutralColors.neutral50;
  static const Color onSurface = NeutralColors.neutral900;
  static const Color onSurfaceSecondary = NeutralColors.neutral600;
  static const Color onSurfaceMuted = NeutralColors.neutral500;
  static const Color surfaceVariant = NeutralColors.neutral100;
  static const Color surfaceContainer = NeutralColors.neutral0;
  static const Color background = NeutralColors.neutral50;

  // Borders & Shadows
  static const Color outline = NeutralColors.neutral200;
  static const Color outlineVariant = NeutralColors.neutral100;
  static const Color shadow = Color(0xFF000000);

  // Semantic
  static const Color success = SemanticColors.success;
  static const Color warning = SemanticColors.warning;
  static const Color info = SemanticColors.info;
}

// ========================================
// DARK MODE COLORS
// ========================================
class DarkModeColors {
  // Brand (adjusted for dark mode)
  static const Color primary = Color(0xFF6BBF47);
  static const Color primaryDark = Color(0xFF4A9A2E);
  static const Color primaryLight = Color(0xFF1A3D12);
  static const Color onPrimary = Color(0xFF0F3A00);
  static const Color primaryContainer = Color(0xFF2A5016);
  static const Color onPrimaryContainer = Color(0xFFD7F2C9);

  // Secondary
  static const Color secondary = Color(0xFFFF8A3D);
  static const Color onSecondary = Color(0xFF4A2000);
  static const Color secondaryContainer = Color(0xFF663300);

  // Tertiary
  static const Color tertiary = Color(0xFF5ACFC5);
  static const Color onTertiary = Color(0xFF003733);

  // Error
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);

  // Surface & Background
  static const Color surface = Color(0xFF1C1C1C);
  static const Color onSurface = Color(0xFFE5E5E5);
  static const Color onSurfaceSecondary = Color(0xFFB0B0B0);
  static const Color onSurfaceMuted = Color(0xFF707070);
  static const Color surfaceVariant = Color(0xFF2A2A2A);
  static const Color surfaceContainer = Color(0xFF242424);
  static const Color background = Color(0xFF121212);

  // Borders & Shadows
  static const Color outline = Color(0xFF3A3A3A);
  static const Color outlineVariant = Color(0xFF2A2A2A);
  static const Color shadow = Color(0xFF000000);

  // Semantic
  static const Color success = Color(0xFF6BBF47);
  static const Color warning = Color(0xFFFF8A3D);
  static const Color info = Color(0xFF5ACFC5);
}

// ========================================
// GRADIENT DEFINITIONS
// ========================================
class WaypointGradients {
  static const LinearGradient brandPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BrandColors.primaryDark, BrandColors.primary],
  );

  static const LinearGradient brandLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [BrandColors.primaryLight, NeutralColors.neutral0],
  );

  static LinearGradient heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.7),
    ],
  );

  static LinearGradient cardOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.4, 1.0],
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.8),
    ],
  );
}
