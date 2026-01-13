import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Waypoint Design System - Typography Tokens
/// 
/// Uses Inter as the primary font family
/// All text styles follow the design specification

class WaypointTypography {
  // ========================================
  // FONT SIZES
  // ========================================
  static const double sizeDisplay = 32.0;
  static const double sizeHeadline = 24.0;
  static const double sizeTitle = 20.0;
  static const double sizeTitleSmall = 18.0;
  static const double sizeBody = 16.0;
  static const double sizeBodySmall = 15.0;
  static const double sizeLabel = 14.0;
  static const double sizeCaption = 13.0;
  static const double sizeSmall = 12.0;
  static const double sizeTiny = 11.0;

  // ========================================
  // TEXT STYLES
  // ========================================
  
  /// Page titles - 32px Bold
  static TextStyle get display => GoogleFonts.inter(
    fontSize: sizeDisplay,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Section headers - 24px SemiBold
  static TextStyle get headline => GoogleFonts.inter(
    fontSize: sizeHeadline,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// Card titles (large) - 20px SemiBold
  static TextStyle get title => GoogleFonts.inter(
    fontSize: sizeTitle,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Card titles - 18px SemiBold
  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: sizeTitleSmall,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Body text - 16px Regular
  static TextStyle get body => GoogleFonts.inter(
    fontSize: sizeBody,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Secondary body - 15px Regular
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: sizeBodySmall,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Labels, buttons - 14px Medium
  static TextStyle get label => GoogleFonts.inter(
    fontSize: sizeLabel,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  /// Captions, metadata - 13px Medium
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: sizeCaption,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
  );

  /// Badges, chips - 12px SemiBold
  static TextStyle get small => GoogleFonts.inter(
    fontSize: sizeSmall,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.3,
  );

  /// Tiny badges - 11px SemiBold
  static TextStyle get tiny => GoogleFonts.inter(
    fontSize: sizeTiny,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // ========================================
  // THEME TEXT THEME
  // ========================================
  static TextTheme buildTextTheme() => TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: 48.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 40.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.0,
    ),
    displaySmall: display,
    headlineLarge: GoogleFonts.inter(
      fontSize: 28.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineMedium: headline,
    headlineSmall: title,
    titleLarge: titleSmall,
    titleMedium: body.copyWith(fontWeight: FontWeight.w600),
    titleSmall: label.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: body,
    bodyMedium: bodySmall,
    bodySmall: caption,
    labelLarge: label.copyWith(fontWeight: FontWeight.w600),
    labelMedium: small,
    labelSmall: tiny,
  );
}
