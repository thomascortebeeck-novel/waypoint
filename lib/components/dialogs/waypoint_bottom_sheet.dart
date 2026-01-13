import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';
import 'package:waypoint/components/buttons/waypoint_button.dart';

/// A styled bottom sheet following the Waypoint design system.
class WaypointBottomSheet extends StatelessWidget {
  const WaypointBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.showDragHandle = true,
    this.showCloseButton = false,
    this.isScrollControlled = true,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool showDragHandle;
  final bool showCloseButton;
  final bool isScrollControlled;

  /// Show a bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeight,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight)
          : null,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: WaypointRadius.topXl,
        boxShadow: WaypointShadows.dialog,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          if (showDragHandle)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: WaypointSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: WaypointRadius.borderFull,
                ),
              ),
            ),
          // Header
          if (title != null || showCloseButton)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WaypointSpacing.lg,
                WaypointSpacing.md,
                WaypointSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: WaypointTypography.title.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: WaypointSpacing.xs),
                          Text(
                            subtitle!,
                            style: WaypointTypography.body.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? DarkModeColors.onSurfaceSecondary
                                  : LightModeColors.onSurfaceSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showCloseButton)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
          // Content
          Flexible(
            child: isScrollControlled
                ? SingleChildScrollView(
                    padding: WaypointSpacing.dialogPadding,
                    child: child,
                  )
                : Padding(
                    padding: WaypointSpacing.dialogPadding,
                    child: child,
                  ),
          ),
          // Actions
          if (actions != null && actions!.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: WaypointSpacing.dialogPadding,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: colorScheme.outline, width: 1),
                  ),
                ),
                child: Row(
                  children: actions!.map((action) {
                    final index = actions!.indexOf(action);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index > 0 ? WaypointSpacing.sm : 0,
                        ),
                        child: action,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Action sheet option
class WaypointActionSheetOption {
  const WaypointActionSheetOption({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isDestructive;
}

/// Action sheet (list of options)
class WaypointActionSheet extends StatelessWidget {
  const WaypointActionSheet({
    super.key,
    this.title,
    required this.options,
    this.cancelLabel = 'Cancel',
  });

  final String? title;
  final List<WaypointActionSheetOption> options;
  final String cancelLabel;

  /// Show an action sheet
  static Future<void> show({
    required BuildContext context,
    String? title,
    required List<WaypointActionSheetOption> options,
  }) {
    return WaypointBottomSheet.show<void>(
      context: context,
      builder: (context) => WaypointActionSheet(
        title: title,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WaypointBottomSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...options.map((option) => _ActionSheetTile(option: option)),
          const SizedBox(height: WaypointSpacing.sm),
          WaypointButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(),
            variant: WaypointButtonVariant.ghost,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _ActionSheetTile extends StatefulWidget {
  const _ActionSheetTile({required this.option});

  final WaypointActionSheetOption option;

  @override
  State<_ActionSheetTile> createState() => _ActionSheetTileState();
}

class _ActionSheetTileState extends State<_ActionSheetTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = widget.option.isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;
    final bgColor = _isPressed
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        Navigator.of(context).pop();
        widget.option.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: WaypointAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: WaypointSpacing.md,
          vertical: WaypointSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: WaypointRadius.borderMd,
        ),
        child: Row(
          children: [
            if (widget.option.icon != null) ...[
              Icon(
                widget.option.icon,
                size: WaypointIconSizes.md,
                color: textColor,
              ),
              const SizedBox(width: WaypointSpacing.md),
            ],
            Expanded(
              child: Text(
                widget.option.label,
                style: WaypointTypography.body.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
