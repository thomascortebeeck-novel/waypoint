import 'package:flutter/material.dart';
import 'colors.dart';

class WaypointTypography {
  // ============================================================
  // FONT SIZE SCALE
  // ============================================================
  static const double sizeDisplay    = 36.0;
  static const double sizeHeadline   = 28.0;
  static const double sizeTitle      = 22.0;
  static const double sizeTitleSmall = 18.0;
  static const double sizeBody       = 16.0;
  static const double sizeBodySmall  = 15.0;
  static const double sizeLabel      = 14.0;
  static const double sizeCaption    = 13.0;
  static const double sizeSmall      = 12.0;
  static const double sizeTiny       = 11.0;

  // ============================================================
  // DISPLAY / HEADING — DM Serif Display
  // Use for: adventure titles, section headers (Stay/Eat/Do),
  //          stat values, price display
  // ============================================================

  /// Adventure/plan title on detail page — 36px
  static TextStyle get displayLargeSerif => TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: sizeDisplay,
    height: 1.15,
    letterSpacing: -0.5,
    color: NeutralColors.textPrimary,
  );

  /// Tab content page title — 28px
  static TextStyle get pageTitleSerif => TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: sizeHeadline,
    height: 1.2,
    letterSpacing: -0.3,
    color: NeutralColors.textPrimary,
  );

  /// Section title (Stay, Eat, Do, Fix) — 22px
  static TextStyle get sectionTitleSerif => TextStyle(
    fontFamily: 'DMSerifDisplay',
    fontSize: sizeTitle,
    height: 1.25,
    color: NeutralColors.textPrimary,
  );

  // ============================================================
  // UI STYLES — DM Sans
  // Use for: body copy, labels, metadata, buttons, chips
  // ============================================================

  static TextStyle get display => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeDisplay,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get headline => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeHeadline,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get title => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeTitle,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get titleSmall => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeTitleSmall,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get body => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeBody,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: NeutralColors.textSecondary,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeBodySmall,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: NeutralColors.textSecondary,
  );

  static TextStyle get label => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeLabel,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeCaption,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
    color: NeutralColors.textSecondary,
  );

  static TextStyle get small => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeSmall,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.3,
    color: NeutralColors.textPrimary,
  );

  static TextStyle get tiny => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeTiny,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
    color: NeutralColors.textSecondary,
  );

  // Tab bar styles
  static TextStyle get tabLabel => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeLabel,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextStyle get tabActive => TextStyle(
    fontFamily: 'DMSans',
    fontSize: sizeLabel,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  // ============================================================
  // MATERIAL TEXT THEME
  // Serif for display/headline slots, DM Sans for body/label
  // ============================================================
  static TextTheme buildTextTheme() => TextTheme(
    displayLarge:   TextStyle(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 48, height: 1.1, letterSpacing: -1.5,
                      color: NeutralColors.textPrimary),
    displayMedium:  TextStyle(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 40, height: 1.15, letterSpacing: -1.0,
                      color: NeutralColors.textPrimary),
    displaySmall:   displayLargeSerif,   // 36px serif — adventure titles
    headlineLarge:  TextStyle(
                      fontFamily: 'DMSerifDisplay',
                      fontSize: 28, height: 1.2, letterSpacing: -0.3,
                      color: NeutralColors.textPrimary),
    headlineMedium: pageTitleSerif,      // 28px serif — tab headings
    headlineSmall:  sectionTitleSerif,   // 22px serif — Stay/Eat/Do headers
    titleLarge:     titleSmall,          // 18px DM Sans SemiBold
    titleMedium:    body.copyWith(fontWeight: FontWeight.w600),
    titleSmall:     label.copyWith(fontWeight: FontWeight.w600),
    bodyLarge:      body,
    bodyMedium:     bodySmall,
    bodySmall:      caption,
    labelLarge:     label.copyWith(fontWeight: FontWeight.w600),
    labelMedium:    small,
    labelSmall:     tiny,
  );
}
