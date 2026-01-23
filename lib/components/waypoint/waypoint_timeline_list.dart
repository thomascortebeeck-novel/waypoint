import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/components/builder/day_timeline_section.dart';
import 'package:waypoint/core/theme/timeline_theme.dart';

/// Reusable waypoints timeline list component
/// Used in builder, trip details, and plan details screens
/// Organizes waypoints by time slot categories with collapsible sections
class WaypointTimelineList extends StatefulWidget {
  final List<RouteWaypoint> waypoints;
  
  // Builder mode callbacks
  final Function(RouteWaypoint)? onEditWaypoint;
  final Function(RouteWaypoint)? onDeleteWaypoint;
  final Function(RouteWaypoint, String?)? onTimeChange;
  final Function(TimeSlotCategory)? onAddWaypoint;
  final Function(int, int)? onReorder;
  
  // Selection mode (for trip owner)
  final bool isSelectable;
  final Set<String> selectedWaypointIds;
  final Function(RouteWaypoint, bool)? onToggleSelection;
  
  // View mode
  final bool isViewOnly;
  final bool showActions; // Show edit/delete actions (builder mode)
  final bool enableTimeEditing; // Allow editing times (builder/trip owner)
  final bool enableReordering; // Allow drag-to-reorder (builder mode)
  
  const WaypointTimelineList({
    super.key,
    required this.waypoints,
    this.onEditWaypoint,
    this.onDeleteWaypoint,
    this.onTimeChange,
    this.onAddWaypoint,
    this.onReorder,
    this.isSelectable = false,
    this.selectedWaypointIds = const {},
    this.onToggleSelection,
    this.isViewOnly = false,
    this.showActions = false,
    this.enableTimeEditing = false,
    this.enableReordering = false,
  });

  @override
  State<WaypointTimelineList> createState() => _WaypointTimelineListState();
}

class _WaypointTimelineListState extends State<WaypointTimelineList> {
  final Map<TimeSlotCategory, bool> _expandedCategories = {};
  
  @override
  void initState() {
    super.initState();
    // Initially expand all categories
    for (final category in TimeSlotCategory.values) {
      _expandedCategories[category] = true;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Group waypoints by time slot category
    final categoryMap = _groupWaypointsByCategory();
    
    // Get ordered categories (only show categories with waypoints)
    final orderedCategories = TimeSlotCategory.values
        .where((cat) => categoryMap[cat]?.isNotEmpty ?? false)
        .toList();
    
    if (orderedCategories.isEmpty) {
      return _buildEmptyState();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedCategories.map((category) {
        final waypoints = categoryMap[category]!;
        final isExpanded = _expandedCategories[category] ?? true;
        
        return DayTimelineSection(
          key: ValueKey(category),
          category: category,
          waypoints: waypoints,
          isExpanded: isExpanded,
          onToggleExpanded: () {
            setState(() {
              _expandedCategories[category] = !isExpanded;
            });
          },
          onAddWaypoint: widget.onAddWaypoint != null 
              ? () => widget.onAddWaypoint!(category) 
              : null,
          onEditWaypoint: widget.onEditWaypoint ?? (_) {},
          onDeleteWaypoint: widget.onDeleteWaypoint ?? (_) {},
          onTimeChange: widget.enableTimeEditing ? widget.onTimeChange : null,
          onReorder: widget.enableReordering ? widget.onReorder : null,
        );
      }).toList(),
    );
  }
  
  /// Group waypoints by their time slot category
  Map<TimeSlotCategory, List<RouteWaypoint>> _groupWaypointsByCategory() {
    final map = <TimeSlotCategory, List<RouteWaypoint>>{};
    
    for (final category in TimeSlotCategory.values) {
      map[category] = [];
    }
    
    for (final waypoint in widget.waypoints) {
      // Auto-assign category if not set
      final category = waypoint.timeSlotCategory ?? 
          autoAssignTimeSlotCategory(waypoint) ??
          TimeSlotCategory.afternoonActivity; // Default fallback
      
      map[category]!.add(waypoint);
    }
    
    // Sort waypoints within each category by order
    for (final list in map.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    
    return map;
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.not_listed_location, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No waypoints for this day',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
