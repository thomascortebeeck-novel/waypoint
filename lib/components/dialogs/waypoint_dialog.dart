import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';
import 'package:waypoint/components/buttons/waypoint_button.dart';

/// Dialog size
enum WaypointDialogSize {
  /// 400px width
  small,
  /// 520px width
  medium,
  /// 640px width
  large,
}

/// A styled dialog component following the Waypoint design system.
class WaypointDialog extends StatelessWidget {
  const WaypointDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.content,
    this.primaryAction,
    this.primaryActionLabel,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.size = WaypointDialogSize.small,
    this.isDanger = false,
    this.showCloseButton = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? content;
  final VoidCallback? primaryAction;
  final String? primaryActionLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;
  final WaypointDialogSize size;
  final bool isDanger;
  final bool showCloseButton;

  /// Factory for confirmation dialog
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDanger = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => WaypointDialog(
        title: title,
        subtitle: message,
        icon: icon,
        primaryAction: () => Navigator.of(context).pop(true),
        primaryActionLabel: confirmLabel,
        secondaryAction: () => Navigator.of(context).pop(false),
        secondaryActionLabel: cancelLabel,
        isDanger: isDanger,
      ),
    );
  }

  /// Factory for alert dialog
  static Future<void> showAlert({
    required BuildContext context,
    required String title,
    String? message,
    String buttonLabel = 'OK',
    IconData? icon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => WaypointDialog(
        title: title,
        subtitle: message,
        icon: icon,
        primaryAction: () => Navigator.of(context).pop(),
        primaryActionLabel: buttonLabel,
        showCloseButton: false,
      ),
    );
  }

  double get _maxWidth {
    switch (size) {
      case WaypointDialogSize.small:
        return WaypointBreakpoints.dialogSmall;
      case WaypointDialogSize.medium:
        return WaypointBreakpoints.dialogMedium;
      case WaypointDialogSize.large:
        return WaypointBreakpoints.dialogLarge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? 
        (isDanger ? colorScheme.error : colorScheme.primary);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: WaypointRadius.borderXl,
          boxShadow: WaypointShadows.dialog,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: WaypointSpacing.dialogPadding,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: effectiveIconColor.withValues(alpha: 0.12),
                        borderRadius: WaypointRadius.borderMd,
                      ),
                      child: Icon(
                        icon,
                        size: WaypointIconSizes.md,
                        color: effectiveIconColor,
                      ),
                    ),
                    const SizedBox(width: WaypointSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
            if (content != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: WaypointSpacing.lg,
                    right: WaypointSpacing.lg,
                    bottom: WaypointSpacing.md,
                  ),
                  child: content,
                ),
              ),
            // Footer
            if (primaryAction != null || secondaryAction != null)
              Container(
                padding: WaypointSpacing.dialogPadding,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: colorScheme.outline, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (secondaryAction != null) ...[
                      WaypointButton(
                        label: secondaryActionLabel ?? 'Cancel',
                        onPressed: secondaryAction,
                        variant: WaypointButtonVariant.ghost,
                      ),
                      const SizedBox(width: WaypointSpacing.sm),
                    ],
                    if (primaryAction != null)
                      WaypointButton(
                        label: primaryActionLabel ?? 'Confirm',
                        onPressed: primaryAction,
                        variant: isDanger 
                            ? WaypointButtonVariant.danger 
                            : WaypointButtonVariant.primary,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
