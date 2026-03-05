import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Reusable "Add" button for section cards (Travel Logistics, Common Questions).
/// Goal design: light lilac/purple background, green plus icon, green text.
/// Use this for "Add Transport Option", "Add FAQ", etc. so styling is DRY.
class SectionAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const SectionAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(
            horizontal: WaypointSpacing.subsectionGap,
            vertical: WaypointSpacing.fieldGap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: WaypointSpacing.gapSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
