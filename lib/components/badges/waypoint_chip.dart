import 'package:flutter/material.dart';
import 'package:waypoint/core/theme/waypoint_theme.dart';

/// A styled chip component for selectable items (filters, categories, types).
class WaypointChip extends StatefulWidget {
  const WaypointChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.leadingIcon,
    this.enabled = true,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final bool enabled;

  @override
  State<WaypointChip> createState() => _WaypointChipState();
}

class _WaypointChipState extends State<WaypointChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.enabled && widget.onTap != null;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (widget.isSelected) {
      backgroundColor = isDark 
          ? DarkModeColors.primaryLight 
          : LightModeColors.primaryLight;
      borderColor = colorScheme.primary;
      textColor = colorScheme.primary;
    } else if (_isHovered && isEnabled) {
      backgroundColor = isDark 
          ? DarkModeColors.surfaceVariant 
          : NeutralColors.neutral100;
      borderColor = isDark 
          ? DarkModeColors.outline 
          : NeutralColors.neutral300;
      textColor = isDark 
          ? DarkModeColors.onSurface 
          : NeutralColors.neutral700;
    } else {
      backgroundColor = isDark 
          ? DarkModeColors.surfaceVariant 
          : NeutralColors.neutral50;
      borderColor = isDark 
          ? DarkModeColors.outline 
          : NeutralColors.neutral200;
      textColor = isDark 
          ? DarkModeColors.onSurface 
          : NeutralColors.neutral700;
    }

    if (!isEnabled) {
      textColor = isDark 
          ? DarkModeColors.onSurfaceMuted 
          : NeutralColors.neutral400;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: WaypointAnimations.fast,
          padding: WaypointSpacing.chipPadding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: WaypointRadius.borderSm,
            border: Border.all(
              color: borderColor,
              width: widget.isSelected 
                  ? WaypointRadius.borderMedium 
                  : WaypointRadius.borderThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leadingIcon != null) ...[
                Icon(
                  widget.leadingIcon,
                  size: WaypointIconSizes.xs,
                  color: widget.isSelected 
                      ? colorScheme.primary 
                      : textColor,
                ),
                const SizedBox(width: WaypointSpacing.xs),
              ],
              Text(
                widget.label,
                style: WaypointTypography.small.copyWith(
                  color: textColor,
                  fontWeight: widget.isSelected 
                      ? FontWeight.w600 
                      : FontWeight.w500,
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: WaypointSpacing.xs),
                Icon(
                  Icons.check_rounded,
                  size: WaypointIconSizes.xs,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A group of chips for multi-select
class WaypointChipGroup extends StatelessWidget {
  const WaypointChipGroup({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.allowMultiple = true,
  });

  final List<String> items;
  final List<String> selectedItems;
  final ValueChanged<List<String>> onSelectionChanged;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: WaypointSpacing.sm,
      runSpacing: WaypointSpacing.sm,
      children: items.map((item) {
        final isSelected = selectedItems.contains(item);
        return WaypointChip(
          label: item,
          isSelected: isSelected,
          onTap: () {
            if (allowMultiple) {
              if (isSelected) {
                onSelectionChanged(
                  selectedItems.where((i) => i != item).toList(),
                );
              } else {
                onSelectionChanged([...selectedItems, item]);
              }
            } else {
              onSelectionChanged(isSelected ? [] : [item]);
            }
          },
        );
      }).toList(),
    );
  }
}
