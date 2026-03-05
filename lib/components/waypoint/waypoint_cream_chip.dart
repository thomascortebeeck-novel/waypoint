import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/colors.dart';
import 'package:waypoint/theme.dart';

/// Reusable cream/green toggle chip used throughout the app.
/// Unselected: cream background (#F0E8D2), brown border, brown text.
/// Selected: forest green background (#2E7D32), white text.
/// When [prominent] is true, unselected chips use surface bg and stronger border for visibility.
class WaypointCreamChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double borderRadius;
  /// When true, chip expands to fill horizontal space (e.g. in a Row with Expanded).
  final bool fillWidth;
  /// Minimum height when used in a row of equal-height pills.
  final double? minHeight;
  /// When true, unselected chips use surface background, stronger border, and dark text for readability (e.g. Explore filters).
  final bool prominent;
  /// Optional icon shown before the label.
  final IconData? icon;

  const WaypointCreamChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.borderRadius = 20,
    this.fillWidth = false,
    this.minHeight,
    this.prominent = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedBg = prominent ? context.colors.surface : context.colors.surfaceContainerHighest;
    final unselectedBorderWidth = prominent ? 1.5 : 1.0;
    final unselectedBorderColor = context.colors.outline;
    final unselectedForeground = context.colors.onSurface;

    Widget chip = Material(
      color: selected ? context.colors.primary : unselectedBg,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            minHeight: minHeight ?? 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: selected
                ? null
                : Border.all(
                    color: unselectedBorderColor,
                    width: unselectedBorderWidth,
                  ),
          ),
          alignment: fillWidth ? Alignment.center : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? context.colors.onPrimary : unselectedForeground,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? context.colors.onPrimary : unselectedForeground,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  letterSpacing: 0,
                  height: 1.25,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    if (fillWidth) chip = SizedBox(width: double.infinity, child: chip);
    return Padding(
      padding: EdgeInsets.only(right: fillWidth ? 0 : 8, bottom: 8),
      child: chip,
    );
  }
}
