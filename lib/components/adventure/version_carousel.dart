import 'package:flutter/material.dart';
import 'package:waypoint/theme/waypoint_colors.dart';
import 'package:waypoint/theme/waypoint_typography.dart';
import 'package:waypoint/theme/waypoint_spacing.dart';
import 'package:waypoint/layout/waypoint_breakpoints.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/models/plan_model.dart';

/// Version carousel component
/// 
/// Horizontal scrolling row of version cards.
/// Shows version name, day count, and activity type.
/// Active card has green border + light green background.
/// Badge shows "Active" for currently selected version.

class VersionCarousel extends StatelessWidget {
  final List<VersionFormState> versions;
  final int activeIndex;
  final Function(int) onSelect;
  final VoidCallback? onAddVersion;
  final ValueChanged<int>? onEdit;
  final ValueChanged<int>? onDelete;
  final bool isBuilder;
  final ActivityCategory? activityCategory;
  
  const VersionCarousel({
    super.key,
    required this.versions,
    required this.activeIndex,
    required this.onSelect,
    this.onAddVersion,
    this.onEdit,
    this.onDelete,
    this.isBuilder = false,
    this.activityCategory,
  });
  
  @override
  Widget build(BuildContext context) {
    if (versions.isEmpty && !isBuilder) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          for (int i = 0; i < versions.length; i++)
            _VersionCard(
              version: versions[i],
              isActive: i == activeIndex,
              activityCategory: activityCategory,
              onTap: () => onSelect(i),
              onEdit: isBuilder && onEdit != null ? () => onEdit!(i) : null,
              onDelete: isBuilder && onDelete != null && versions.length > 1 
                  ? () => onDelete!(i) 
                  : null,
            ),
          // Add version card (builder only)
          if (isBuilder && onAddVersion != null)
            _AddVersionCard(onTap: onAddVersion!),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final VersionFormState version;
  final bool isActive;
  final ActivityCategory? activityCategory;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  const _VersionCard({
    required this.version,
    required this.isActive,
    this.activityCategory,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    final cardWidth = isMobile ? 200.0 : 240.0;
    
    final dayCount = version.daysCount;
    final activityLabel = _getActivityLabel(activityCategory);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: WaypointSpacing.gapSm),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isActive ? WaypointColors.primarySurface : WaypointColors.surface,
          border: Border.all(
            color: isActive ? WaypointColors.primary : WaypointColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version name
                Text(
                  version.nameCtrl.text.isEmpty ? 'Untitled Version' : version.nameCtrl.text,
                  style: WaypointTypography.headlineMedium.copyWith(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6.0),
                // Day count + activity
                Text(
                  '$dayCount ${dayCount == 1 ? 'day' : 'days'}${activityLabel != null ? ' • $activityLabel' : ''}',
                  style: WaypointTypography.bodyMedium.copyWith(
                    color: WaypointColors.textSecondary,
                  ),
                ),
              ],
            ),
            // Active badge
            if (isActive)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: WaypointColors.primary,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    'Active',
                    style: WaypointTypography.chipLabel.copyWith(
                      fontSize: 10.0,
                      color: WaypointColors.surface,
                    ),
                  ),
                ),
              ),
            // Edit/Delete menu (builder mode only)
            // Position on left side if active (to avoid Active badge), otherwise top-right
            if (onEdit != null || onDelete != null)
              Positioned(
                top: 4,
                right: isActive ? null : 4,
                left: isActive ? 4 : null,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit' && onEdit != null) {
                      onEdit!();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: isActive 
                        ? WaypointColors.surface.withOpacity(0.8) 
                        : WaypointColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String? _getActivityLabel(ActivityCategory? category) {
    if (category == null) return null;
    switch (category) {
      case ActivityCategory.hiking:
        return 'Hiking';
      case ActivityCategory.cycling:
        return 'Cycling';
      case ActivityCategory.skis:
        return 'Skiing';
      case ActivityCategory.climbing:
        return 'Climbing';
      case ActivityCategory.cityTrips:
        return 'City Trips';
      case ActivityCategory.tours:
        return 'Tours';
      case ActivityCategory.roadTripping:
        return 'Road Tripping';
    }
  }
}

class _AddVersionCard extends StatelessWidget {
  final VoidCallback onTap;
  
  const _AddVersionCard({required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = WaypointBreakpoints.isMobile(screenWidth);
    final cardWidth = isMobile ? 200.0 : 240.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: WaypointSpacing.gapSm),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: WaypointColors.surface,
          border: Border.all(
            color: WaypointColors.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(WaypointSpacing.cardRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              size: 24.0,
              color: WaypointColors.textTertiary,
            ),
            const SizedBox(height: 6.0),
            Text(
              'Add version',
              style: WaypointTypography.bodyMedium.copyWith(
                color: WaypointColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

