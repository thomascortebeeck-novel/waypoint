import 'package:flutter/material.dart';
import 'package:waypoint/models/route_waypoint.dart';
import 'package:waypoint/models/orderable_item.dart';
import 'package:waypoint/components/waypoint/unified_waypoint_card.dart';
import 'package:waypoint/components/reorder_controls.dart';
import 'package:waypoint/core/theme/colors.dart';

/// Builds the day content as a flat ordered list
/// Each item (section or individual waypoint) can be moved up/down freely
class DayContentBuilder extends StatelessWidget {
  final int dayNumber;
  final List<OrderableItem> orderedItems;
  final Map<String, List<RouteWaypoint>> waypointsBySectionId;
  final Map<String, RouteWaypoint> waypointsById;
  
  // Callbacks
  final Function(String itemId) onMoveUp;
  final Function(String itemId) onMoveDown;
  final bool Function(String itemId) canMoveUp;
  final bool Function(String itemId) canMoveDown;
  
  final Function(RouteWaypoint) onEditWaypoint;
  final Function(RouteWaypoint) onDeleteWaypoint;
  final Function(OrderableItemType type, String? sectionType)? onAddWaypoint;
  
  // View mode
  final bool showActions;
  final bool isViewOnly;
  
  const DayContentBuilder({
    super.key,
    required this.dayNumber,
    required this.orderedItems,
    required this.waypointsBySectionId,
    required this.waypointsById,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEditWaypoint,
    required this.onDeleteWaypoint,
    this.onAddWaypoint,
    this.showActions = true,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sort items by order
    final sorted = List<OrderableItem>.from(orderedItems)
      ..sort((a, b) => a.order.compareTo(b.order));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in sorted)
          _buildItem(context, item),
      ],
    );
  }
  
  Widget _buildItem(BuildContext context, OrderableItem item) {
    if (item.isSection) {
      return _buildSectionItem(context, item);
    } else {
      return _buildIndividualWaypointItem(context, item);
    }
  }
  
  /// Build a section item (Restaurant subcategory, Activity subcategory, Accommodation)
  Widget _buildSectionItem(BuildContext context, OrderableItem item) {
    final sectionId = item.id;
    final waypoints = waypointsBySectionId[sectionId] ?? [];
    
    // Get section display info
    final displayInfo = _getSectionDisplayInfo(item);
    
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with reorder controls
          _buildSectionHeader(context, item, displayInfo, waypoints.length),
          
          // Section content (waypoints)
          if (waypoints.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: displayInfo.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (final wp in waypoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildWaypointCard(context, wp, showReorderControls: false),
                    ),
                ],
              ),
            ),
          
          // Add waypoint button for this section
          if (showActions && !isViewOnly && onAddWaypoint != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 8),
              child: _buildAddButton(context, item.type, item.sectionType, displayInfo.color),
            ),
        ],
      ),
    );
  }
  
  /// Build an individual waypoint item (Logistics, Viewing Point)
  Widget _buildIndividualWaypointItem(BuildContext context, OrderableItem item) {
    final waypoint = waypointsById[item.waypointId];
    if (waypoint == null) return const SizedBox.shrink();
    
    final displayInfo = _getIndividualWaypointDisplayInfo(item, waypoint);
    
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          _buildTimelineNode(displayInfo.icon, displayInfo.color, isSmall: true),
          const SizedBox(width: 12),
          
          // Waypoint card
          Expanded(
            child: _buildWaypointCard(context, waypoint, showReorderControls: false),
          ),
          
          // Reorder controls (vertical)
          if (!isViewOnly) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ReorderControlsVertical(
                canMoveUp: canMoveUp(item.id),
                canMoveDown: canMoveDown(item.id),
                onMoveUp: () => onMoveUp(item.id),
                onMoveDown: () => onMoveDown(item.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(
    BuildContext context, 
    OrderableItem item, 
    _DisplayInfo displayInfo,
    int waypointCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Timeline node
          _buildTimelineNode(displayInfo.icon, displayInfo.color),
          const SizedBox(width: 12),
          
          // Label and count
          Expanded(
            child: Row(
              children: [
                Text(
                  displayInfo.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (waypointCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: displayInfo.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$waypointCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: displayInfo.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Reorder controls for sections (horizontal)
          if (!isViewOnly)
            ReorderControls(
              canMoveUp: canMoveUp(item.id),
              canMoveDown: canMoveDown(item.id),
              onMoveUp: () => onMoveUp(item.id),
              onMoveDown: () => onMoveDown(item.id),
              isCompact: true,
            ),
        ],
      ),
    );
  }
  
  Widget _buildTimelineNode(IconData icon, Color color, {bool isSmall = false}) {
    final size = isSmall ? 28.0 : 32.0;
    final iconSize = isSmall ? 14.0 : 16.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
  
  Widget _buildWaypointCard(BuildContext context, RouteWaypoint waypoint, {required bool showReorderControls}) {
    return UnifiedWaypointCard(
      waypoint: waypoint,
      showActions: showActions,
      onEdit: showActions ? () => onEditWaypoint(waypoint) : null,
      onDelete: showActions ? () => onDeleteWaypoint(waypoint) : null,
      showDragHandle: false,
      isViewOnly: isViewOnly,
      isCompact: true,
    );
  }
  
  Widget _buildAddButton(BuildContext context, OrderableItemType type, String? sectionType, Color color) {
    return InkWell(
      onTap: () => onAddWaypoint?.call(type, sectionType),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  _DisplayInfo _getSectionDisplayInfo(OrderableItem item) {
    switch (item.type) {
      case OrderableItemType.restaurantSection:
        return _getRestaurantDisplayInfo(item.sectionType);
      case OrderableItemType.activitySection:
        return _getActivityDisplayInfo(item.sectionType);
      case OrderableItemType.accommodationSection:
        return _DisplayInfo(
          icon: Icons.hotel,
          color: const Color(0xFF7C3AED), // Purple
          label: 'Accommodation',
        );
      default:
        return _DisplayInfo(
          icon: Icons.place,
          color: Colors.grey,
          label: 'Unknown',
        );
    }
  }
  
  _DisplayInfo _getRestaurantDisplayInfo(String? mealTime) {
    switch (mealTime) {
      case 'breakfast':
        return _DisplayInfo(
          icon: Icons.free_breakfast,
          color: const Color(0xFFF59E0B), // Amber
          label: 'Breakfast',
        );
      case 'lunch':
        return _DisplayInfo(
          icon: Icons.lunch_dining,
          color: const Color(0xFFEF4444), // Red
          label: 'Lunch',
        );
      case 'dinner':
        return _DisplayInfo(
          icon: Icons.dinner_dining,
          color: const Color(0xFF8B5CF6), // Violet
          label: 'Dinner',
        );
      default:
        return _DisplayInfo(
          icon: Icons.restaurant,
          color: const Color(0xFFEF4444),
          label: 'Restaurant',
        );
    }
  }
  
  _DisplayInfo _getActivityDisplayInfo(String? activityTime) {
    switch (activityTime) {
      case 'morning':
        return _DisplayInfo(
          icon: Icons.wb_sunny,
          color: const Color(0xFFF59E0B), // Amber
          label: 'Morning Activity',
        );
      case 'afternoon':
        return _DisplayInfo(
          icon: Icons.wb_twilight,
          color: const Color(0xFF3B82F6), // Blue
          label: 'Afternoon Activity',
        );
      case 'night':
        return _DisplayInfo(
          icon: Icons.nightlight,
          color: const Color(0xFF6366F1), // Indigo
          label: 'Night Activity',
        );
      case 'allDay':
        return _DisplayInfo(
          icon: Icons.all_inclusive,
          color: const Color(0xFF10B981), // Emerald
          label: 'All Day Activity',
        );
      case 'evening':
        return _DisplayInfo(
          icon: Icons.nightlight_round,
          color: const Color(0xFF6366F1), // Indigo
          label: 'Evening Activity',
        );
      default:
        return _DisplayInfo(
          icon: Icons.local_activity,
          color: const Color(0xFF3B82F6),
          label: 'Activity',
        );
    }
  }
  
  _DisplayInfo _getIndividualWaypointDisplayInfo(OrderableItem item, RouteWaypoint waypoint) {
    switch (item.type) {
      case OrderableItemType.logisticsWaypoint:
        // Use logistics category icon
        final logisticsCat = waypoint.serviceCategory ?? waypoint.logisticsCategory;
        if (logisticsCat != null) {
          switch (logisticsCat) {
            case ServiceCategory.gear:
              return _DisplayInfo(
                icon: Icons.backpack,
                color: const Color(0xFF4CAF50), // Green
                label: 'Logistics - Gear',
              );
            case ServiceCategory.transportation:
              return _DisplayInfo(
                icon: Icons.directions_car,
                color: const Color(0xFF4CAF50), // Green
                label: 'Logistics - Transportation',
              );
            case ServiceCategory.food:
              return _DisplayInfo(
                icon: Icons.shopping_bag,
                color: const Color(0xFF4CAF50), // Green
                label: 'Logistics - Food',
              );
            default:
              break;
          }
        }
        return _DisplayInfo(
          icon: Icons.local_gas_station,
          color: const Color(0xFF64748B), // Slate
          label: 'Logistics',
        );
      case OrderableItemType.viewingPointWaypoint:
        return _DisplayInfo(
          icon: Icons.visibility,
          color: const Color(0xFF14B8A6), // Teal
          label: 'Viewing Point',
        );
      default:
        return _DisplayInfo(
          icon: Icons.place,
          color: Colors.grey,
          label: 'Waypoint',
        );
    }
  }
}

class _DisplayInfo {
  final IconData icon;
  final Color color;
  final String label;
  
  _DisplayInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}

