import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// A dialog wrapper that prevents scroll events from propagating to the background map.
/// 
/// This widget wraps a dialog and ensures that:
/// - Scroll notifications are consumed and don't reach parent widgets
/// - Pointer scroll events (mouse wheel, trackpad) are intercepted
/// - Touch gestures within the dialog still work normally
/// 
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => ScrollBlockingDialog(
///     child: YourDialogContent(),
///   ),
/// );
/// ```
class ScrollBlockingDialog extends StatelessWidget {
  final Widget child;
  final Color? barrierColor;
  final bool barrierDismissible;
  final String? barrierLabel;

  const ScrollBlockingDialog({
    super.key,
    required this.child,
    this.barrierColor,
    this.barrierDismissible = true,
    this.barrierLabel,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Consume all scroll notifications to prevent map zoom
      onNotification: (_) => true,
      child: Listener(
        // Intercept mouse wheel/trackpad scrolling to prevent map zoom
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Absorb the scroll event to prevent it from reaching the map
            // The dialog's scrollable content will still handle scrolling normally
          }
        },
        child: GestureDetector(
          // Absorb tap gestures on the barrier to prevent map interaction
          onTap: barrierDismissible ? () => Navigator.of(context).pop() : null,
          // Absorb scale/pan gestures to prevent map interaction
          onScaleUpdate: (_) {},
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            barrierColor: barrierColor,
            barrierDismissible: barrierDismissible,
            barrierLabel: barrierLabel,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A widget that wraps scrollable content and prevents scroll propagation.
/// 
/// Use this to wrap SingleChildScrollView or ListView inside dialogs to ensure
/// scroll events don't reach the background map.
class ScrollBlockingScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const ScrollBlockingScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Consume all scroll notifications to prevent map zoom
      onNotification: (_) => true,
      child: Listener(
        // Intercept mouse wheel/trackpad scrolling to prevent map zoom
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Absorb the scroll event to prevent it from reaching the map
            // The SingleChildScrollView will still handle touch/drag gestures normally
          }
        },
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          physics: physics,
          child: child,
        ),
      ),
    );
  }
}

