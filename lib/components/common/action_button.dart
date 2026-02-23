import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';

/// Reusable action button component
/// 
/// Consistent icon button styling used across the app.
/// Supports hover states and custom sizes.

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool isEnabled;
  
  const ActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.size = 34.0,
    this.iconSize = 16.0,
    this.tooltip,
    this.isEnabled = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: isEnabled && onTap != null 
          ? SystemMouseCursors.click 
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? WaypointColors.surface,
            border: Border.all(
              color: borderColor ?? WaypointColors.border,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? WaypointColors.textSecondary,
          ),
        ),
      ),
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    
    return button;
  }
}

