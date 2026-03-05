import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Card wrapper with title, icon, and optional edit actions
/// Used throughout the unified screen for consistent section styling
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  /// Optional icon color (e.g. primary green for Common Questions).
  final Color? iconColor;
  /// Optional title color (e.g. primary green for Common Questions so it's not dark).
  final Color? titleColor;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final bool isEditable;
  final EdgeInsets? padding;

  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.titleColor,
    required this.children,
    this.onEdit,
    this.isEditable = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colors.primary;
    final effectiveTitleColor = titleColor ?? colors.onSurface;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: WaypointSpacing.subsectionGap,
        vertical: WaypointSpacing.gapSm,
      ),
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(WaypointSpacing.subsectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: effectiveIconColor),
                  const SizedBox(width: WaypointSpacing.gapSm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: effectiveTitleColor,
                    ),
                  ),
                ),
                if (isEditable && onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
              ],
            ),
            const SizedBox(height: WaypointSpacing.fieldGap),
            ...children,
          ],
        ),
      ),
    );
  }
}

