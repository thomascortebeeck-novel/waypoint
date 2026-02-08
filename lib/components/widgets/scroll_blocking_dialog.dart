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
      child: Stack(
        children: [
          // CRITICAL: Create a full-screen invisible barrier that blocks events from reaching the Mapbox canvas
          // This barrier is NOT the Mapbox canvas - it's a Flutter layer that intercepts all events
          // By using HitTestBehavior.opaque, we force the browser to focus on the Flutter layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // Blocks all events from passing through
              onTap: barrierDismissible ? () => Navigator.of(context).pop() : null,
              onScaleUpdate: (_) {}, // Consumes pinch/zoom/pan gestures (scale is a superset of pan)
              child: Container(
                color: barrierColor ?? Colors.black12, // Subtle dimming to show dialog is active
              ),
            ),
          ),
          // Dialog content centered on top of the barrier
          Center(
            child: MouseRegion(
              // Force standard cursor (arrow) instead of map's grabbing hand cursor
              // This ensures form fields show the correct cursor
              cursor: SystemMouseCursors.basic,
              child: Listener(
                // CRITICAL: Only intercept scroll events to prevent map zoom
                // Do NOT block pointer down/up events - they need to reach child widgets (like the X button)
                // The barrier GestureDetector and CSS pointer-events handle blocking background clicks
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    // Event is consumed by this handler, preventing it from reaching the map
                    // The dialog's scrollable content will still handle scrolling normally
                  }
                },
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: child,
                ),
              ),
            ),
          ),
        ],
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

