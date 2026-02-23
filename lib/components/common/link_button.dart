import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Reusable link button component
/// 
/// Consistent link button styling for external links, actions, etc.
/// Used in ExternalLinksRow and other places.

class LinkButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  
  const LinkButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 6.0,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? WaypointColors.surface,
          border: Border.all(
            color: borderColor ?? WaypointColors.border,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 12.0),
            ),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: textColor ?? WaypointColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

