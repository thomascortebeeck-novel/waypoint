import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// Button variants following the design system
enum WaypointButtonVariant {
  /// Primary actions - filled with brand color
  primary,
  /// Secondary actions - outlined
  secondary,
  /// Tertiary actions - transparent
  tertiary,
  /// Subtle actions - ghost button
  ghost,
  /// Destructive actions - danger
  danger,
  /// Subtle destructive - dangerGhost
  dangerGhost,
}

/// Button sizes
enum WaypointButtonSize {
  /// 36px height
  small,
  /// 44px height
  medium,
  /// 52px height
  large,
}

/// A styled button component following the Waypoint design system.
///
/// Example:
/// ```dart
/// WaypointButton(
///   label: 'Save',
///   onPressed: () {},
///   variant: WaypointButtonVariant.primary,
/// )
/// ```
class WaypointButton extends StatefulWidget {
  const WaypointButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = WaypointButtonVariant.primary,
    this.size = WaypointButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final WaypointButtonVariant variant;
  final WaypointButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final bool enabled;

  @override
  State<WaypointButton> createState() => _WaypointButtonState();
}

class _WaypointButtonState extends State<WaypointButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
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

  double get _height {
    switch (widget.size) {
      case WaypointButtonSize.small:
        return 36;
      case WaypointButtonSize.medium:
        return 44;
      case WaypointButtonSize.large:
        return 52;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case WaypointButtonSize.small:
        return WaypointSpacing.buttonSmall;
      case WaypointButtonSize.medium:
        return WaypointSpacing.buttonStandard;
      case WaypointButtonSize.large:
        return WaypointSpacing.buttonLarge;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case WaypointButtonSize.small:
        return WaypointIconSizes.xs;
      case WaypointButtonSize.medium:
        return WaypointIconSizes.sm;
      case WaypointButtonSize.large:
        return 22;
    }
  }

  TextStyle get _textStyle {
    final baseStyle = widget.size == WaypointButtonSize.small
        ? WaypointTypography.caption
        : WaypointTypography.label;
    return baseStyle.copyWith(fontWeight: FontWeight.w600);
  }

  Color _getBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (widget.variant) {
      case WaypointButtonVariant.primary:
        return colorScheme.primary;
      case WaypointButtonVariant.secondary:
      case WaypointButtonVariant.tertiary:
      case WaypointButtonVariant.ghost:
        return Colors.transparent;
      case WaypointButtonVariant.danger:
        return colorScheme.error;
      case WaypointButtonVariant.dangerGhost:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (widget.variant) {
      case WaypointButtonVariant.primary:
        return colorScheme.onPrimary;
      case WaypointButtonVariant.secondary:
        return colorScheme.primary;
      case WaypointButtonVariant.tertiary:
        return isDark ? DarkModeColors.onSurface : NeutralColors.neutral700;
      case WaypointButtonVariant.ghost:
        return isDark ? DarkModeColors.onSurfaceSecondary : NeutralColors.neutral600;
      case WaypointButtonVariant.danger:
        return colorScheme.onError;
      case WaypointButtonVariant.dangerGhost:
        return colorScheme.error;
    }
  }

  BorderSide? _getBorder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (widget.variant) {
      case WaypointButtonVariant.secondary:
        return BorderSide(
          color: colorScheme.primary,
          width: WaypointRadius.borderThick,
        );
      case WaypointButtonVariant.dangerGhost:
        return BorderSide(
          color: colorScheme.error.withValues(alpha: 0.5),
          width: WaypointRadius.borderThin,
        );
      default:
        return null;
    }
  }

  List<BoxShadow>? _getShadow(BuildContext context) {
    if (widget.variant == WaypointButtonVariant.primary && !widget.isLoading) {
      return WaypointShadows.button;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !widget.isLoading && widget.onPressed != null;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
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
          child: AnimatedContainer(
            duration: WaypointAnimations.fast,
            height: _height,
            width: widget.isFullWidth ? double.infinity : null,
            padding: _padding,
            decoration: BoxDecoration(
              color: _getBackgroundColor(context),
              borderRadius: WaypointRadius.borderMd,
              border: _getBorder(context) != null
                  ? Border.fromBorderSide(_getBorder(context)!)
                  : null,
              boxShadow: _getShadow(context),
            ),
            child: Row(
              mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        _getForegroundColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: WaypointSpacing.sm),
                ] else if (widget.leadingIcon != null) ...[
                  Icon(
                    widget.leadingIcon,
                    size: _iconSize,
                    color: _getForegroundColor(context),
                  ),
                  const SizedBox(width: WaypointSpacing.sm),
                ],
                Text(
                  widget.label,
                  style: _textStyle.copyWith(
                    color: _getForegroundColor(context),
                  ),
                ),
                if (widget.trailingIcon != null && !widget.isLoading) ...[
                  const SizedBox(width: WaypointSpacing.sm),
                  Icon(
                    widget.trailingIcon,
                    size: _iconSize,
                    color: _getForegroundColor(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
