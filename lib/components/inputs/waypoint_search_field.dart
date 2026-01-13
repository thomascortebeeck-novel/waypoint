import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// A styled search field component following the Waypoint design system.
class WaypointSearchField extends StatefulWidget {
  const WaypointSearchField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<WaypointSearchField> createState() => _WaypointSearchFieldState();
}

class _WaypointSearchFieldState extends State<WaypointSearchField> {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = isDark 
        ? DarkModeColors.surfaceVariant 
        : NeutralColors.neutral100;
    final iconColor = isDark 
        ? DarkModeColors.onSurfaceMuted 
        : LightModeColors.onSurfaceMuted;

    return AnimatedContainer(
      duration: WaypointAnimations.fast,
      height: 44,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: WaypointRadius.borderFull,
        border: Border.all(
          color: _isFocused 
              ? colorScheme.primary.withValues(alpha: 0.5) 
              : Colors.transparent,
          width: _isFocused 
              ? WaypointRadius.borderMedium 
              : WaypointRadius.borderThin,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: WaypointIconSizes.sm,
            color: _isFocused ? colorScheme.primary : iconColor,
          ),
          const SizedBox(width: WaypointSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: WaypointTypography.body.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: WaypointTypography.body.copyWith(
                  color: iconColor,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (_hasText) ...[
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onChanged?.call('');
                widget.onClear?.call();
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: WaypointIconSizes.xs,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: WaypointSpacing.sm),
          ] else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
