import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// Trailing content type for settings item
enum SettingsItemTrailing {
  /// Chevron icon (navigation)
  chevron,
  /// Switch toggle
  toggle,
  /// Text value
  value,
  /// Custom widget
  custom,
  /// None
  none,
}

/// A styled settings list item following the Waypoint design system.
class SettingsItem extends StatefulWidget {
  const SettingsItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingIconBackgroundColor,
    this.trailingType = SettingsItemTrailing.chevron,
    this.trailingWidget,
    this.value,
    this.isToggled,
    this.onTap,
    this.onToggle,
    this.showDivider = true,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Color? leadingIconBackgroundColor;
  final SettingsItemTrailing trailingType;
  final Widget? trailingWidget;
  final String? value;
  final bool? isToggled;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final bool showDivider;
  final bool enabled;

  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.enabled && (widget.onTap != null || widget.onToggle != null);

    final iconColor = widget.leadingIconColor ?? colorScheme.primary;
    final iconBgColor = widget.leadingIconBackgroundColor ?? 
        (isDark ? DarkModeColors.surfaceVariant : NeutralColors.neutral100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: isEnabled ? (_) {
            setState(() => _isPressed = false);
            widget.onTap?.call();
          } : null,
          onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
          child: AnimatedContainer(
            duration: WaypointAnimations.fast,
            color: _isPressed 
                ? colorScheme.onSurface.withValues(alpha: 0.05) 
                : Colors.transparent,
            padding: WaypointSpacing.paddingMd,
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.5,
              child: Row(
                children: [
                  // Leading icon
                  if (widget.leadingIcon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: WaypointRadius.borderSm,
                      ),
                      child: Icon(
                        widget.leadingIcon,
                        size: WaypointIconSizes.sm,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: WaypointSpacing.md),
                  ],
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: WaypointTypography.body.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: WaypointTypography.caption.copyWith(
                              color: isDark 
                                  ? DarkModeColors.onSurfaceMuted 
                                  : LightModeColors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Trailing
                  _buildTrailing(context),
                ],
              ),
            ),
          ),
        ),
        // Divider
        if (widget.showDivider)
          Padding(
            padding: EdgeInsets.only(
              left: widget.leadingIcon != null ? 68.0 : WaypointSpacing.md,
            ),
            child: Divider(
              height: 1,
              color: colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.trailingType) {
      case SettingsItemTrailing.chevron:
        return Icon(
          Icons.chevron_right_rounded,
          size: WaypointIconSizes.md,
          color: isDark 
              ? DarkModeColors.onSurfaceMuted 
              : LightModeColors.onSurfaceMuted,
        );
      case SettingsItemTrailing.toggle:
        return Switch.adaptive(
          value: widget.isToggled ?? false,
          onChanged: widget.enabled ? widget.onToggle : null,
          activeColor: colorScheme.primary,
        );
      case SettingsItemTrailing.value:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.value != null)
              Text(
                widget.value!,
                style: WaypointTypography.body.copyWith(
                  color: isDark 
                      ? DarkModeColors.onSurfaceMuted 
                      : LightModeColors.onSurfaceMuted,
                ),
              ),
            const SizedBox(width: WaypointSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: WaypointIconSizes.md,
              color: isDark 
                  ? DarkModeColors.onSurfaceMuted 
                  : LightModeColors.onSurfaceMuted,
            ),
          ],
        );
      case SettingsItemTrailing.custom:
        return widget.trailingWidget ?? const SizedBox.shrink();
      case SettingsItemTrailing.none:
        return const SizedBox.shrink();
    }
  }
}

/// Settings section with title and items
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    required this.items,
  });

  final String? title;
  final List<SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WaypointSpacing.md,
              WaypointSpacing.lg,
              WaypointSpacing.md,
              WaypointSpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: WaypointTypography.small.copyWith(
                color: isDark 
                    ? DarkModeColors.onSurfaceMuted 
                    : LightModeColors.onSurfaceMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(color: colorScheme.outline, width: 1),
              bottom: BorderSide(color: colorScheme.outline, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return SettingsItem(
                title: entry.value.title,
                subtitle: entry.value.subtitle,
                leadingIcon: entry.value.leadingIcon,
                leadingIconColor: entry.value.leadingIconColor,
                leadingIconBackgroundColor: entry.value.leadingIconBackgroundColor,
                trailingType: entry.value.trailingType,
                trailingWidget: entry.value.trailingWidget,
                value: entry.value.value,
                isToggled: entry.value.isToggled,
                onTap: entry.value.onTap,
                onToggle: entry.value.onToggle,
                showDivider: !isLast,
                enabled: entry.value.enabled,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
