import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';

/// Section header component
/// 
/// Row with colored icon box, title, and optional add button.
/// Used for grouping POI sections (Stay, Eat, Do, Fix).

class SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;
  final Color tintColor;
  final VoidCallback? onAdd; // Shows "+" button when non-null
  final Widget? trailing; // Optional trailing widget
  
  const SectionHeader({
    super.key,
    required this.title,
    required this.emoji,
    required this.tintColor,
    this.onAdd,
    this.trailing,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        top: WaypointSpacing.sectionGap,
        bottom: 14.0,
      ),
      padding: const EdgeInsets.only(bottom: 10.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: WaypointColors.borderLight,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 28.0,
            height: 28.0,
            decoration: BoxDecoration(
              color: _getSurfaceColor(tintColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 13.0),
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          // Title
          Text(
            title,
            style: WaypointTypography.headlineMedium,
          ),
          const Spacer(),
          // Trailing widget or add button
          if (trailing != null)
            trailing!
          else if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 30.0,
                height: 30.0,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: WaypointColors.primaryLight,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add,
                  size: 16.0,
                  color: WaypointColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Color _getSurfaceColor(Color tintColor) {
    // Return light surface color based on tint
    if (tintColor == WaypointColors.catStay) return WaypointColors.catStaySurface;
    if (tintColor == WaypointColors.catEat) return WaypointColors.catEatSurface;
    if (tintColor == WaypointColors.catDo) return WaypointColors.catDoSurface;
    if (tintColor == WaypointColors.catFix) return WaypointColors.catFixSurface;
    return WaypointColors.borderLight;
  }
}

