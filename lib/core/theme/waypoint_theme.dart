import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';
import 'radius.dart';
import 'shadows.dart';
import 'animations.dart';

export 'colors.dart';
export 'typography.dart';
export 'spacing.dart';
export 'radius.dart';
export 'shadows.dart';
export 'animations.dart';
export 'package:waypoint/core/constants/breakpoints.dart';
export 'package:waypoint/core/constants/icon_sizes.dart';

/// Waypoint Design System Theme Provider
/// 
/// Access theme tokens using WaypointTheme.of(context) or the extension methods:
/// - context.colors for ColorScheme
/// - context.textStyles for TextTheme

ThemeData get waypointLightTheme => ThemeData(
  useMaterial3: true,
  fontFamily: 'DMSans', // DM Sans replaces Inter
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
  // AppBar — white/minimal, no Hunter Green banner
  appBarTheme: const AppBarTheme(
    backgroundColor: LightModeColors.surface,              // white
    foregroundColor: LightModeColors.onSurface,            // #212529
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: false,
    iconTheme: IconThemeData(color: LightModeColors.onSurfaceSecondary),
  ),
  // Tab bar — Hunter Green indicator on white background
  tabBarTheme: TabBarThemeData(
    indicatorColor:       LightModeColors.primary,         // #1B4332
    indicatorSize:        TabBarIndicatorSize.label,
    labelColor:           LightModeColors.primary,
    unselectedLabelColor: LightModeColors.onSurfaceMuted,  // #6C757D
    labelStyle:           WaypointTypography.tabActive,
    unselectedLabelStyle: WaypointTypography.tabLabel,
    dividerColor:         LightModeColors.outline,
  ),
  // Cards — white with platinum border, no elevation
  cardTheme: CardThemeData(
    elevation: 0,
    color: LightModeColors.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: LightModeColors.outline, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  // Input fields — Platinum fill, Hunter Green focus
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: NeutralColors.backgroundPrimary,            // #F8F9FA
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NeutralColors.backgroundSecondary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NeutralColors.backgroundSecondary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: LightModeColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SemanticColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: WaypointTypography.body
                 .copyWith(color: NeutralColors.neutral500),
    labelStyle: WaypointTypography.label
                  .copyWith(color: NeutralColors.textSecondary),
  ),
  // Elevated button — Hunter Green bg
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: LightModeColors.primary,
      foregroundColor: LightModeColors.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: WaypointTypography.label,
      shadowColor: Colors.transparent,
    ),
  ),
  // Outlined button — Hunter Green border
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: LightModeColors.primary, width: 1.5),
      textStyle: WaypointTypography.label,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: WaypointTypography.label,
    ),
  ),
  // FAB — Maize Yellow for high visibility
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    elevation: 6,
    backgroundColor: BrandColors.secondary,                // #FCBF49
    foregroundColor: NeutralColors.textPrimary,            // dark for contrast
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  // Chips — platinum bg, Hunter Green selected
  chipTheme: ChipThemeData(
    backgroundColor:  NeutralColors.backgroundSecondary,   // #E9ECEF
    selectedColor:    BrandColors.primary,                 // #1B4332
    labelStyle:       WaypointTypography.small
                        .copyWith(color: NeutralColors.textPrimary),
    side:             const BorderSide(color: NeutralColors.neutral300),
    padding:          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    shape:            const StadiumBorder(),
  ),
  // Navigation bar — white bg, Hunter Green selected
  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    backgroundColor: LightModeColors.surface,
    indicatorColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return WaypointTypography.small
            .copyWith(color: LightModeColors.primary);
      }
      return WaypointTypography.small
          .copyWith(color: LightModeColors.onSurfaceMuted);
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(size: 24, color: LightModeColors.primary);
      }
      return const IconThemeData(size: 24, color: LightModeColors.onSurfaceMuted);
    }),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: LightModeColors.surfaceContainer,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: WaypointRadius.borderXl,
    ),
  ),
  // Bottom sheet and dialog unchanged structurally
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: LightModeColors.surface,
    elevation: 0,
    showDragHandle: true,
    dragHandleColor: NeutralColors.neutral300,
    dragHandleSize: Size(40, 4),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: NeutralColors.neutral900,             // #212529
    contentTextStyle: WaypointTypography.body
                        .copyWith(color: NeutralColors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  // Dividers — Platinum
  dividerTheme: const DividerThemeData(
    color: NeutralColors.backgroundSecondary,
    thickness: 1,
    space: 1,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: LightModeColors.primary,
    linearTrackColor: NeutralColors.backgroundSecondary,
  ),
  textTheme: WaypointTypography.buildTextTheme(),
);

ThemeData get waypointDarkTheme => ThemeData(
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
      borderRadius: WaypointRadius.borderLg,
      side: const BorderSide(color: DarkModeColors.outline, width: WaypointRadius.borderThin),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: WaypointRadius.borderMd,
      borderSide: const BorderSide(color: DarkModeColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: WaypointRadius.borderMd,
      borderSide: const BorderSide(color: DarkModeColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: WaypointRadius.borderMd,
      borderSide: const BorderSide(color: DarkModeColors.primary, width: WaypointRadius.borderThick),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: WaypointRadius.borderMd,
      borderSide: const BorderSide(color: DarkModeColors.error),
    ),
    contentPadding: WaypointSpacing.inputPadding,
    hintStyle: WaypointTypography.body.copyWith(color: DarkModeColors.onSurfaceMuted),
    labelStyle: WaypointTypography.label.copyWith(color: DarkModeColors.onSurfaceSecondary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: DarkModeColors.primary,
      foregroundColor: DarkModeColors.onPrimary,
      padding: WaypointSpacing.buttonStandard,
      shape: RoundedRectangleBorder(
        borderRadius: WaypointRadius.borderMd,
      ),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: WaypointTypography.sizeLabel,
        letterSpacing: 0.1,
      ),
      shadowColor: Colors.transparent,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.primary,
      padding: WaypointSpacing.buttonStandard,
      shape: RoundedRectangleBorder(
        borderRadius: WaypointRadius.borderMd,
      ),
      side: const BorderSide(color: DarkModeColors.primary, width: WaypointRadius.borderThick),
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: WaypointTypography.sizeLabel,
        letterSpacing: 0.1,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: DarkModeColors.primary,
      padding: WaypointSpacing.buttonStandard,
      textStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: WaypointTypography.sizeLabel,
      ),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    elevation: 4,
    backgroundColor: DarkModeColors.secondary,
    foregroundColor: Colors.white,
    extendedPadding: WaypointSpacing.buttonStandard,
    shape: RoundedRectangleBorder(
      borderRadius: WaypointRadius.borderLg,
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: DarkModeColors.surfaceVariant,
    selectedColor: DarkModeColors.primaryLight,
    labelStyle: WaypointTypography.small.copyWith(color: DarkModeColors.onSurface),
    side: const BorderSide(color: DarkModeColors.outline),
    shape: RoundedRectangleBorder(
      borderRadius: WaypointRadius.borderSm,
    ),
    padding: WaypointSpacing.chipPadding,
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
          fontSize: WaypointTypography.sizeSmall,
          fontWeight: FontWeight.w600,
          color: DarkModeColors.primary,
        );
      }
      return GoogleFonts.inter(
        fontSize: WaypointTypography.sizeSmall,
        fontWeight: FontWeight.w500,
        color: DarkModeColors.onSurfaceMuted,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(size: 24, color: DarkModeColors.primary);
      }
      return const IconThemeData(size: 24, color: DarkModeColors.onSurfaceMuted);
    }),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: DarkModeColors.surfaceContainer,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: WaypointRadius.borderXl,
    ),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: DarkModeColors.surfaceContainer,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: WaypointRadius.topXl,
    ),
    dragHandleColor: DarkModeColors.outline,
    dragHandleSize: const Size(40, 4),
    showDragHandle: true,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: DarkModeColors.onSurface,
    contentTextStyle: WaypointTypography.body.copyWith(color: DarkModeColors.surface),
    shape: RoundedRectangleBorder(
      borderRadius: WaypointRadius.borderMd,
    ),
    behavior: SnackBarBehavior.floating,
  ),
  dividerTheme: const DividerThemeData(
    color: DarkModeColors.outline,
    thickness: 1,
    space: 1,
  ),
  textTheme: WaypointTypography.buildTextTheme(),
);
