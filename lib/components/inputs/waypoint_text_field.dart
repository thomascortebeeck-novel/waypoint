import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// Input field size
enum WaypointInputSize {
  /// 40px height
  small,
  /// 48px height
  medium,
  /// 56px height
  large,
}

/// A styled text field component following the Waypoint design system.
class WaypointTextField extends StatefulWidget {
  const WaypointTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.size = WaypointInputSize.medium,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.validator,
    this.showClearButton = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final WaypointInputSize size;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool showClearButton;

  @override
  State<WaypointTextField> createState() => _WaypointTextFieldState();
}

class _WaypointTextFieldState extends State<WaypointTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  double get _height {
    if (widget.maxLines > 1) return double.infinity;
    switch (widget.size) {
      case WaypointInputSize.small:
        return 40;
      case WaypointInputSize.medium:
        return 48;
      case WaypointInputSize.large:
        return 56;
    }
  }

  EdgeInsets get _contentPadding {
    switch (widget.size) {
      case WaypointInputSize.small:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      case WaypointInputSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
      case WaypointInputSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  TextStyle get _textStyle {
    switch (widget.size) {
      case WaypointInputSize.small:
        return WaypointTypography.bodySmall;
      case WaypointInputSize.medium:
      case WaypointInputSize.large:
        return WaypointTypography.body;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null;

    Color fillColor;
    Color borderColor;

    if (hasError) {
      fillColor = isDark ? DarkModeColors.surfaceVariant : LightModeColors.surfaceVariant;
      borderColor = colorScheme.error;
    } else if (_isFocused) {
      fillColor = isDark ? DarkModeColors.surface : NeutralColors.neutral0;
      borderColor = colorScheme.primary;
    } else {
      fillColor = isDark ? DarkModeColors.surfaceVariant : LightModeColors.surfaceVariant;
      borderColor = colorScheme.outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: WaypointTypography.label.copyWith(
              color: hasError 
                  ? colorScheme.error 
                  : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: WaypointSpacing.sm),
        ],
        AnimatedContainer(
          duration: WaypointAnimations.fast,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: WaypointRadius.borderMd,
            border: Border.all(
              color: borderColor,
              width: _isFocused || hasError 
                  ? WaypointRadius.borderThick 
                  : WaypointRadius.borderThin,
            ),
            boxShadow: _isFocused && !hasError
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            style: _textStyle.copyWith(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: _textStyle.copyWith(
                color: isDark 
                    ? DarkModeColors.onSurfaceMuted 
                    : LightModeColors.onSurfaceMuted,
              ),
              contentPadding: _contentPadding,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Icon(
                        widget.prefixIcon,
                        size: WaypointIconSizes.sm,
                        color: _isFocused
                            ? colorScheme.primary
                            : (isDark 
                                ? DarkModeColors.onSurfaceMuted 
                                : LightModeColors.onSurfaceMuted),
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _buildSuffixIcon(context),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              counterText: '',
            ),
          ),
        ),
        if (widget.errorText != null || widget.helperText != null) ...[
          const SizedBox(height: WaypointSpacing.xs),
          Text(
            widget.errorText ?? widget.helperText!,
            style: WaypointTypography.caption.copyWith(
              color: hasError 
                  ? colorScheme.error 
                  : (isDark 
                      ? DarkModeColors.onSurfaceMuted 
                      : LightModeColors.onSurfaceMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.showClearButton && _hasText) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: WaypointIconSizes.xs,
            color: isDark 
                ? DarkModeColors.onSurfaceMuted 
                : LightModeColors.onSurfaceMuted,
          ),
          onPressed: () {
            _controller.clear();
            widget.onChanged?.call('');
          },
          splashRadius: 16,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      );
    }

    if (widget.suffixIcon != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 14, left: 8),
        child: GestureDetector(
          onTap: widget.onSuffixTap,
          child: Icon(
            widget.suffixIcon,
            size: WaypointIconSizes.sm,
            color: _isFocused
                ? colorScheme.primary
                : (isDark 
                    ? DarkModeColors.onSurfaceMuted 
                    : LightModeColors.onSurfaceMuted),
          ),
        ),
      );
    }

    return null;
  }
}
