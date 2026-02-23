import 'package:flutter/material.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';

/// Breadcrumb navigation component
/// 
/// Activity-based breadcrumb trail: Back to Explore / [Activity] / [Adventure Title]
/// Follows AllTrails navigation pattern.

class BreadcrumbNav extends StatelessWidget {
  final ActivityCategory? activityCategory;
  final String adventureTitle;
  final List<LocationInfo>? locations;
  final VoidCallback? onBackToExplore;
  final VoidCallback? onActivityTap;
  
  const BreadcrumbNav({
    super.key,
    this.activityCategory,
    required this.adventureTitle,
    this.locations,
    this.onBackToExplore,
    this.onActivityTap,
  });
  
  String _getActivityLabel(ActivityCategory? category) {
    if (category == null) return '';
    // Capitalize first letter
    final name = category.name;
    return name[0].toUpperCase() + name.substring(1);
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    
    // On mobile, can hide or truncate breadcrumbs
    String displayTitle = adventureTitle;
    if (isMobile && adventureTitle.length > 30) {
      // Truncate on mobile if title is too long
      displayTitle = adventureTitle.substring(0, 27) + '...';
    }
    
    return _buildBreadcrumbs(context, displayTitle);
  }
  
  Widget _buildBreadcrumbs(BuildContext context, String displayTitle) {
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back to Explore link
          GestureDetector(
            onTap: onBackToExplore,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                '← Back to Explore',
                style: WaypointTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: WaypointColors.primary,
                  decoration: onBackToExplore != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
          
          // Activity type (if available)
          if (activityCategory != null) ...[
            const SizedBox(width: 8),
            Text(
              ' / ',
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: WaypointColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onActivityTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  _getActivityLabel(activityCategory),
                  style: WaypointTypography.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: onActivityTap != null 
                        ? WaypointColors.textPrimary 
                        : WaypointColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
          
          // Locations (if available, show first location or first + count)
          if (locations != null && locations!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              ' / ',
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: WaypointColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              locations!.length <= 2
                  ? locations!.map((l) => l.shortName).join(' / ')
                  : '${locations!.first.shortName} + ${locations!.length - 1} more',
              style: WaypointTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: WaypointColors.textSecondary,
              ),
            ),
          ],
          
          // Adventure title (current page, no link)
          const SizedBox(width: 8),
          Text(
            ' / ',
            style: WaypointTypography.bodyMedium.copyWith(
              fontSize: 13,
              color: WaypointColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            displayTitle,
            style: WaypointTypography.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WaypointColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

