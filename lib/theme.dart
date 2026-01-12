import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0; // More rounded for modern look
  static const double lg = 24.0;
  static const double xl = 32.0;
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

class LightModeColors {
  // AllTrails-Inspired Professional Palette
  static const primary = Color(0xFF428A13); // AllTrails Signature Green
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE8F5E0);
  static const onPrimaryContainer = Color(0xFF0D2E00);

  static const secondary = Color(0xFFFF6D00); // Vibrant Orange for CTAs
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFFEDD5);
  
  static const tertiary = Color(0xFF2B7A78); // Teal for accents
  static const onTertiary = Color(0xFFFFFFFF);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);

  // Professional neutral backgrounds
  static const surface = Color(0xFFFAFAFA); // Soft off-white
  static const onSurface = Color(0xFF1A1C19);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const surfaceContainer = Color(0xFFFFFFFF); // Pure white for cards
  static const background = Color(0xFFFAFAFA);
  
  static const outline = Color(0xFFE0E0E0);
  static const outlineVariant = Color(0xFFF0F0F0);
  static const shadow = Color(0xFF000000);
  
  // Semantic colors
  static const success = Color(0xFF428A13);
  static const warning = Color(0xFFFF8C42);
  static const info = Color(0xFF2B7A78);
}

class DarkModeColors {
  // AllTrails Dark Mode Professional Palette
  static const primary = Color(0xFF6BBF47); // Lighter green for dark backgrounds
  static const onPrimary = Color(0xFF0F3A00);
  static const primaryContainer = Color(0xFF2A5016);
  static const onPrimaryContainer = Color(0xFFD7F2C9);

  static const secondary = Color(0xFFFF8A3D); // Warm orange
  static const onSecondary = Color(0xFF4A2000);
  static const secondaryContainer = Color(0xFF663300);

  static const tertiary = Color(0xFF5ACFC5); // Bright teal
  static const onTertiary = Color(0xFF003733);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);

  // Professional dark backgrounds
  static const surface = Color(0xFF1C1C1C); // Rich dark surface
  static const onSurface = Color(0xFFE5E5E5);
  static const surfaceVariant = Color(0xFF2A2A2A);
  static const surfaceContainer = Color(0xFF242424); // Cards in dark mode
  static const background = Color(0xFF121212); // Deep background
  
  static const outline = Color(0xFF3A3A3A);
  static const outlineVariant = Color(0xFF2A2A2A);
  static const shadow = Color(0xFF000000);
  
  // Semantic colors
  static const success = Color(0xFF6BBF47);
  static const warning = Color(0xFFFF8A3D);
  static const info = Color(0xFF5ACFC5);
}

class FontSizes {
  static const double displayLarge = 48.0;
  static const double displayMedium = 40.0;
  static const double displaySmall = 32.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.primary,
    onPrimary: LightModeColors.onPrimary,
    primaryContainer: LightModeColors.primaryContainer,
    onPrimaryContainer: LightModeColors.onPrimaryContainer,
    secondary: LightModeColors.secondary,
    onSecondary: LightModeColors.onSecondary,
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
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.onSurface,
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shadowColor: Colors.black.withValues(alpha: 0.04),
    color: LightModeColors.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: LightModeColors.outlineVariant, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: LightModeColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: LightModeColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: LightModeColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: LightModeColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
      shadowColor: Colors.transparent,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: const BorderSide(color: LightModeColors.primary, width: 2),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    elevation: 4,
    backgroundColor: LightModeColors.secondary,
    foregroundColor: Colors.white,
    extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.primary,
    onPrimary: DarkModeColors.onPrimary,
    primaryContainer: DarkModeColors.primaryContainer,
    onPrimaryContainer: DarkModeColors.onPrimaryContainer,
    secondary: DarkModeColors.secondary,
    onSecondary: DarkModeColors.onSecondary,
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
    color: DarkModeColors.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: DarkModeColors.outlineVariant, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: DarkModeColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: DarkModeColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: DarkModeColors.primary, width: 2),
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
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.3,
      ),
      shadowColor: Colors.transparent,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

TextTheme _buildTextTheme(Brightness brightness) {
  // AllTrails-inspired typography: Inter for everything (clean, modern, web-friendly)
  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.15,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );
}
