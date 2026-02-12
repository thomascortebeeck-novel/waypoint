import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// A dialog wrapper that prevents scroll events from propagating to the background map.
/// 
/// Uses [PointerInterceptor] to block browser-level DOM events from reaching
/// Platform Views (Google Maps HtmlElementView) on Flutter web.
/// Flutter's standard gesture system (GestureDetector, Listener, AbsorbPointer)
/// cannot intercept events targeting Platform Views because they are HTML elements
/// that receive browser events directly, bypassing Flutter's rendering pipeline.
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
          // CRITICAL: Full-screen barrier using PointerInterceptor to block
          // browser-level DOM events from reaching the Google Maps Platform View.
          // PointerInterceptor creates an invisible HTML element that sits above
          // the Platform View in the DOM, intercepting events before they reach it.
          Positioned.fill(
            child: PointerInterceptor(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: barrierDismissible ? () => Navigator.of(context).pop() : null,
                child: Container(
                  color: barrierColor ?? Colors.black12,
                ),
              ),
            ),
          ),
          // Dialog content - also wrapped in PointerInterceptor to ensure
          // scroll events within the dialog don't leak to the map
          Center(
            child: PointerInterceptor(
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
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
      onNotification: (_) => true,
      child: NotificationListener<OverscrollNotification>(
        onNotification: (_) => true,
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          physics: physics ?? const ClampingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}
