import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// Icon button variant
enum WaypointIconButtonVariant {
  /// Filled background
  filled,
  /// Tinted background (light primary)
  tinted,
  /// Outlined border
  outlined,
  /// Ghost (no background)
  ghost,
}

/// Icon button size
enum WaypointIconButtonSize {
  /// 32px
  small,
  /// 40px
  medium,
  /// 48px
  large,
}

/// A styled icon button component following the Waypoint design system.
class WaypointIconButton extends StatefulWidget {
  const WaypointIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = WaypointIconButtonVariant.ghost,
    this.size = WaypointIconButtonSize.medium,
    this.color,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final WaypointIconButtonVariant variant;
  final WaypointIconButtonSize size;
  final Color? color;
  final String? tooltip;
  final bool enabled;

  @override
  State<WaypointIconButton> createState() => _WaypointIconButtonState();
}

class _WaypointIconButtonState extends State<WaypointIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: WaypointAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: WaypointAnimations.buttonPressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: WaypointAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _size {
    switch (widget.size) {
      case WaypointIconButtonSize.small:
        return 32;
      case WaypointIconButtonSize.medium:
        return 40;
      case WaypointIconButtonSize.large:
        return 48;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case WaypointIconButtonSize.small:
        return WaypointIconSizes.xs;
      case WaypointIconButtonSize.medium:
        return WaypointIconSizes.sm;
      case WaypointIconButtonSize.large:
        return WaypointIconSizes.md;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = widget.color ?? colorScheme.primary;
    
    switch (widget.variant) {
      case WaypointIconButtonVariant.filled:
        return baseColor;
      case WaypointIconButtonVariant.tinted:
        return baseColor.withValues(alpha: 0.12);
      case WaypointIconButtonVariant.outlined:
      case WaypointIconButtonVariant.ghost:
        return _isHovered 
            ? colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.transparent;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = widget.color ?? colorScheme.primary;
    
    switch (widget.variant) {
      case WaypointIconButtonVariant.filled:
        return colorScheme.onPrimary;
      case WaypointIconButtonVariant.tinted:
      case WaypointIconButtonVariant.outlined:
      case WaypointIconButtonVariant.ghost:
        return baseColor;
    }
  }

  BorderSide? _getBorder(BuildContext context) {
    if (widget.variant == WaypointIconButtonVariant.outlined) {
      final baseColor = widget.color ?? Theme.of(context).colorScheme.primary;
      return BorderSide(
        color: baseColor.withValues(alpha: 0.5),
        width: WaypointRadius.borderThin,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && widget.onPressed != null;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) {
          setState(() => _isPressed = true);
          _controller.forward();
        } : null,
        onTapUp: isEnabled ? (_) {
          setState(() => _isPressed = false);
          _controller.reverse();
          widget.onPressed?.call();
        } : null,
        onTapCancel: isEnabled ? () {
          setState(() => _isPressed = false);
          _controller.reverse();
        } : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isPressed ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: AnimatedContainer(
              duration: WaypointAnimations.fast,
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: _getBackgroundColor(context),
                borderRadius: WaypointRadius.borderMd,
                border: _getBorder(context) != null
                    ? Border.fromBorderSide(_getBorder(context)!)
                    : null,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: _iconSize,
                  color: _getIconColor(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}
