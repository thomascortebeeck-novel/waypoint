import 'package:flutter/material.dart';

/// Waypoint Design System - Shadow Tokens

class WaypointShadows {
  // ========================================
  // ELEVATION SCALE
  // ========================================
  
  /// No shadow - flat elements
  static const List<BoxShadow> none = [];

  /// Subtle lift - 0 1px 2px rgba(0,0,0,0.04)
  static List<BoxShadow> xs = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Cards, inputs - 0 2px 4px rgba(0,0,0,0.06)
  static List<BoxShadow> sm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Elevated cards, dropdowns - 0 4px 12px rgba(0,0,0,0.08)
  static List<BoxShadow> md = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Modals, popovers - 0 8px 24px rgba(0,0,0,0.12)
  static List<BoxShadow> lg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Large modals - 0 16px 48px rgba(0,0,0,0.16)
  static List<BoxShadow> xl = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 48,
      offset: const Offset(0, 16),
    ),
  ];

  // ========================================
  // SPECIALIZED SHADOWS
  // ========================================

  /// Default card shadow
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Card hover state
  static List<BoxShadow> cardHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Primary button shadow
  static List<BoxShadow> button = [
    BoxShadow(
      color: const Color(0xFF428A13).withValues(alpha: 0.25),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Bottom navigation shadow
  static List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, -2),
    ),
  ];

  /// Dialog and modal shadow
  static List<BoxShadow> dialog = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 60,
      offset: const Offset(0, 20),
    ),
  ];

  /// Sidebar shadow
  static List<BoxShadow> sidebar = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(2, 0),
    ),
  ];
}
