import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/core/theme/radius.dart';

// Re-export the new design system for gradual migration
export 'package:waypoint/core/theme/waypoint_theme.dart';
export 'package:waypoint/components/components.dart';

/// Legacy spacing - use WaypointSpacing from the new design system
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Legacy radius - use WaypointRadius from the new design system
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
  TextStyle withOpacity(double opacity) => copyWith(color: color?.withValues(alpha: opacity));
}

class FontSizes {
  static const double displayLarge = 48.0;
  static const double displayMedium = 40.0;
  static const double displaySmall = 32.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 18.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelSmall = 11.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: LightModeColors.primary,
    onPrimary: LightModeColors.onPrimary,
    primaryContainer: LightModeColors.primaryContainer,
    onPrimaryContainer: LightModeColors.onPrimaryContainer,
    secondary: LightModeColors.secondary,
    onSecondary: LightModeColors.onSecondary,
    secondaryContainer: LightModeColors.secondaryContainer,
    tertiary: LightModeColors.tertiary,
    onTertiary: LightModeColors.onTertiary,
    error: LightModeColors.error,
    onError: LightModeColors.onError,
    surface: LightModeColors.surface,
    onSurface: LightModeColors.onSurface,
    outline: LightModeColors.outline,
    shadow: LightModeColors.shadow,
  ),
  scaffoldBackgroundColor: LightModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: LightModeColors.primary,
    foregroundColor: LightModeColors.onPrimary,
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
    iconTheme: IconThemeData(color: LightModeColors.onPrimary),
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shadowColor: LightModeColors.shadow.withValues(alpha: 0.08),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      side: BorderSide.none,
    ),
    margin: EdgeInsets.zero,
  ),
  listTileTheme: ListTileThemeData(
    selectedColor: LightModeColors.primary,
    selectedTileColor: LightModeColors.primary.withValues(alpha: 0.08),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: LightModeColors.backgroundSecondary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: LightModeColors.backgroundSecondary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: LightModeColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: SemanticColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: NeutralColors.textSecondary),
    hintStyle: TextStyle(color: NeutralColors.textSecondary.withValues(alpha: 0.6)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 2,
      backgroundColor: LightModeColors.primary,
      foregroundColor: LightModeColors.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WaypointRadius.md),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WaypointRadius.md),
      ),
      side: const BorderSide(color: LightModeColors.primary, width: 1),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    elevation: 6,
    backgroundColor: LightModeColors.secondary,
    foregroundColor: NeutralColors.textPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(WaypointRadius.lg)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: NeutralColors.backgroundSecondary,
    selectedColor: LightModeColors.primary,
    labelStyle: const TextStyle(color: NeutralColors.textPrimary),
    secondaryLabelStyle: const TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.sm),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: NeutralColors.textSecondary,
    contentTextStyle: TextStyle(color: Colors.white),
    actionTextColor: Colors.white,
    behavior: SnackBarBehavior.floating,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Colors.white,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: NeutralColors.textPrimary,
    ),
    contentTextStyle: TextStyle(
      fontSize: 16,
      color: NeutralColors.textSecondary,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(WaypointRadius.lg)),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: LightModeColors.primary,
    linearTrackColor: LightModeColors.backgroundSecondary,
    circularTrackColor: LightModeColors.backgroundSecondary,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return LightModeColors.secondary;
      }
      return Colors.white;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return LightModeColors.primary;
      }
      return LightModeColors.backgroundSecondary;
    }),
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: LightModeColors.primary,
    thumbColor: LightModeColors.secondary,
    inactiveTrackColor: LightModeColors.backgroundSecondary,
  ),
  dividerTheme: const DividerThemeData(
    color: LightModeColors.backgroundSecondary,
    thickness: 1,
  ),
  iconTheme: const IconThemeData(
    color: NeutralColors.textSecondary,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: LightModeColors.primary,
        );
      }
      return GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: NeutralColors.textSecondary,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(
          size: 24,
          color: LightModeColors.primary,
        );
      }
      return const IconThemeData(
        size: 24,
        color: NeutralColors.textSecondary,
      );
    }),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

// We keep the dark theme defined but it generally maps to the same structure 
// with DarkModeColors. 
// Note: The prompt didn't strictly specify full dark mode palette mapping beyond 
// the colors we added to colors.dart, so we do a best-effort mapping here.
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: DarkModeColors.primary,
    onPrimary: DarkModeColors.onPrimary,
    primaryContainer: DarkModeColors.primaryContainer,
    onPrimaryContainer: DarkModeColors.onPrimaryContainer,
    secondary: DarkModeColors.secondary,
    onSecondary: DarkModeColors.onSecondary,
    secondaryContainer: DarkModeColors.secondaryContainer,
    tertiary: DarkModeColors.tertiary,
    onTertiary: DarkModeColors.onTertiary,
    error: DarkModeColors.error,
    onError: DarkModeColors.onError,
    surface: DarkModeColors.surface,
    onSurface: DarkModeColors.onSurface,
    outline: DarkModeColors.outline,
    shadow: DarkModeColors.shadow,
  ),
  scaffoldBackgroundColor: DarkModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.onSurface,
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    color: DarkModeColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      side: const BorderSide(color: DarkModeColors.outline, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(WaypointRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: DarkModeColors.primary,
      foregroundColor: DarkModeColors.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WaypointRadius.md),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WaypointRadius.md),
      ),
      side: const BorderSide(color: DarkModeColors.primary, width: 2),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    elevation: 4,
    backgroundColor: DarkModeColors.secondary,
    foregroundColor: Colors.white,
    extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(WaypointRadius.lg)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    backgroundColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: DarkModeColors.primary,
        );
      }
      return GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: DarkModeColors.onSurfaceMuted,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(
          size: 24,
          color: DarkModeColors.primary,
        );
      }
      return const IconThemeData(
        size: 24,
        color: DarkModeColors.onSurfaceMuted,
      );
    }),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

TextTheme _buildTextTheme(Brightness brightness) {
  final textColor = brightness == Brightness.light 
      ? NeutralColors.textPrimary 
      : DarkModeColors.onSurface;
      
  final secondaryColor = brightness == Brightness.light
      ? NeutralColors.textSecondary
      : DarkModeColors.onSurfaceSecondary;

  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      color: textColor,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
      color: textColor,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: textColor,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: textColor,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.15,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.15,
      color: textColor,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: textColor,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: secondaryColor,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: secondaryColor,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: secondaryColor,
    ),
  );
}
