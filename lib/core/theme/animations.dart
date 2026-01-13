import 'package:flutter/material.dart';

/// Waypoint Design System - Animation Tokens

class WaypointAnimations {
  // ========================================
  // DURATION SCALE
  // ========================================
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 500);

  // ========================================
  // EASING CURVES
  // ========================================
  
  /// Standard transitions
  static const Curve defaultCurve = Curves.easeInOut;
  
  /// Exit animations
  static const Curve easeIn = Curves.easeIn;
  
  /// Enter animations
  static const Curve easeOut = Curves.easeOut;
  
  /// Symmetric animations
  static const Curve easeInOut = Curves.easeInOut;
  
  /// Bouncy, playful - cubic-bezier(0.34, 1.56, 0.64, 1)
  static const Curve spring = Curves.elasticOut;
  
  /// Smooth, subtle
  static const Curve smooth = Curves.ease;

  // ========================================
  // ANIMATION PRESETS
  // ========================================

  /// Fade In animation
  static Widget fadeIn({
    required Widget child,
    required Animation<double> animation,
  }) => FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: easeOut,
    ),
    child: child,
  );

  /// Slide Up animation
  static Widget slideUp({
    required Widget child,
    required Animation<double> animation,
  }) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: easeOut,
    )),
    child: FadeTransition(
      opacity: animation,
      child: child,
    ),
  );

  /// Scale In animation
  static Widget scaleIn({
    required Widget child,
    required Animation<double> animation,
  }) => ScaleTransition(
    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: easeOut),
    ),
    child: FadeTransition(
      opacity: animation,
      child: child,
    ),
  );

  // ========================================
  // HOVER ANIMATION VALUES
  // ========================================
  
  /// Card hover lift
  static const double cardHoverLift = -4.0;
  
  /// Card hover scale
  static const double cardHoverScale = 1.02;
  
  /// Button press scale
  static const double buttonPressScale = 0.98;
  
  /// Icon bounce scale
  static const double iconBounceScale = 1.2;
}
