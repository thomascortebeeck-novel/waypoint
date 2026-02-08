import 'package:flutter/foundation.dart';
import 'package:waypoint/models/route_waypoint.dart' show RouteWaypoint, WaypointType, MealTime, ActivityTime, LogisticsCategory, TimeSlotCategory, autoAssignTimeSlotCategory;

/// Represents any orderable item in a day plan
/// Can be either:
/// - A SECTION (restaurant subcategory, activity subcategory, accommodation) containing multiple waypoints
/// - An INDIVIDUAL WAYPOINT (logistics, viewing point) that stands alone
/// 
/// All items exist in a single flat ordered list per day.
@immutable
class OrderableItem {
  final String id;              // Unique identifier
  final OrderableItemType type; // Section or individual waypoint
  final int order;              // Position in the day (0-based)
  
  // For sections (restaurant/activity/accommodation)
  final String? sectionType;    // e.g., "breakfast", "morning", null for accommodation
  
  // For individual waypoints (logistics/viewing point)
  final String? waypointId;     // The actual waypoint ID
  
  const OrderableItem({
    required this.id,
    required this.type,
    required this.order,
    this.sectionType,
    this.waypointId,
  });
  
  OrderableItem copyWith({int? order}) {
    return OrderableItem(
      id: id,
      type: type,
      order: order ?? this.order,
      sectionType: sectionType,
      waypointId: waypointId,
    );
  }
  
  /// Create ID for a section
  static String createSectionId(OrderableItemType type, String? sectionType) {
    if (sectionType != null) {
      return '${type.name}_$sectionType';
    }
    return type.name;
  }
  
  /// Create ID for an individual waypoint
  static String createWaypointItemId(OrderableItemType type, String waypointId) {
    return '${type.name}_wp_$waypointId';
  }
  
  bool get isSection => type == OrderableItemType.restaurantSection ||
                        type == OrderableItemType.activitySection ||
                        type == OrderableItemType.accommodationSection;
  
  bool get isIndividualWaypoint => type == OrderableItemType.logisticsWaypoint ||
                                    type == OrderableItemType.viewingPointWaypoint;
}

enum OrderableItemType {
  // Sections (contain multiple waypoints, moved as a group)
  restaurantSection,      // Breakfast, Lunch, Dinner sections
  activitySection,        // Morning, Afternoon, Night, All Day sections
  accommodationSection,   // Accommodation section
  
  // Individual waypoints (each waypoint is its own item)
  logisticsWaypoint,      // Each logistics waypoint
  viewingPointWaypoint,   // Each viewing point waypoint
}

/// Manages the flat ordered list of items for a day
class DayPlanOrderManager {
  final int dayNumber;
  final List<OrderableItem> items;
  
  DayPlanOrderManager({
    required this.dayNumber,
    required this.items,
  });
  
  /// Get items sorted by order
  List<OrderableItem> get sortedItems {
    final sorted = List<OrderableItem>.from(items);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }
  
  /// Move an item up (swap with previous)
  DayPlanOrderManager moveUp(String itemId) {
    final sorted = sortedItems;
    final index = sorted.indexWhere((item) => item.id == itemId);
    if (index <= 0) return this;
    
    return _swapItems(sorted[index], sorted[index - 1]);
  }
  
  /// Move an item down (swap with next)
  DayPlanOrderManager moveDown(String itemId) {
    final sorted = sortedItems;
    final index = sorted.indexWhere((item) => item.id == itemId);
    if (index < 0 || index >= sorted.length - 1) return this;
    
    return _swapItems(sorted[index], sorted[index + 1]);
  }
  
  DayPlanOrderManager _swapItems(OrderableItem a, OrderableItem b) {
    final newItems = items.map((item) {
      if (item.id == a.id) return item.copyWith(order: b.order);
      if (item.id == b.id) return item.copyWith(order: a.order);
      return item;
    }).toList();
    
    return DayPlanOrderManager(dayNumber: dayNumber, items: newItems);
  }
  
  bool canMoveUp(String itemId) {
    final sorted = sortedItems;
    final index = sorted.indexWhere((item) => item.id == itemId);
    return index > 0;
  }
  
  bool canMoveDown(String itemId) {
    final sorted = sortedItems;
    final index = sorted.indexWhere((item) => item.id == itemId);
    return index >= 0 && index < sorted.length - 1;
  }
  
  /// Add a new item at the end
  DayPlanOrderManager addItem(OrderableItem item) {
    final maxOrder = items.isEmpty ? -1 : items.map((i) => i.order).reduce((a, b) => a > b ? a : b);
    final newItem = item.copyWith(order: maxOrder + 1);
    return DayPlanOrderManager(
      dayNumber: dayNumber,
      items: [...items, newItem],
    );
  }
  
  /// Remove an item and reorder remaining
  DayPlanOrderManager removeItem(String itemId) {
    final newItems = items.where((item) => item.id != itemId).toList();
    // Reorder to fill gaps
    final sorted = List<OrderableItem>.from(newItems)
      ..sort((a, b) => a.order.compareTo(b.order));
    final reordered = sorted.asMap().entries
        .map((e) => e.value.copyWith(order: e.key))
        .toList();
    
    return DayPlanOrderManager(dayNumber: dayNumber, items: reordered);
  }
}

/// Utility to create the initial order from waypoints
class DayPlanOrderBuilder {
  /// Build initial ordered items from a list of waypoints
  /// Preserves existing section order based on waypoint order field
  static DayPlanOrderManager buildFromWaypoints(
    int dayNumber,
    List<RouteWaypoint> waypoints,
  ) {
    final items = <OrderableItem>[];
    final seenSections = <String>{};
    final sectionFirstOrder = <String, int>{}; // Track first order value for each section
    
    // Default ordering template (used only when no existing order is found)
    final defaultOrder = <String, int>{
      'accommodationSection': 0,
      'restaurantSection_breakfast': 1,
      'activitySection_morning': 2,
      'restaurantSection_lunch': 3,
      'activitySection_afternoon': 4,
      'activitySection_allDay': 5,
      'restaurantSection_dinner': 6,
      'activitySection_evening': 7,
      'activitySection_night': 8,
    };
    
    int currentOrder = 0;
    int logisticsOrder = 100; // Logistics/viewing points start at 100
    
    // First pass: identify all sections and track their first occurrence order
    for (final wp in waypoints) {
      final category = wp.timeSlotCategory ?? autoAssignTimeSlotCategory(wp);
      String? sectionId;
      
      switch (wp.type) {
        case WaypointType.restaurant:
          final mealTime = wp.mealTime?.name ?? 'lunch';
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.restaurantSection, 
            mealTime,
          );
          break;
          
        case WaypointType.activity:
          final activityTime = wp.activityTime?.name ?? 'afternoon';
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.activitySection,
            activityTime,
          );
          break;
          
        case WaypointType.accommodation:
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.accommodationSection,
            null,
          );
          break;
          
        case WaypointType.servicePoint: // Logistics - each waypoint is individual
          items.add(OrderableItem(
            id: OrderableItem.createWaypointItemId(
              OrderableItemType.logisticsWaypoint,
              wp.id,
            ),
            type: OrderableItemType.logisticsWaypoint,
            order: logisticsOrder++,
            waypointId: wp.id,
          ));
          break;
          
        case WaypointType.viewingPoint: // Each waypoint is individual
          items.add(OrderableItem(
            id: OrderableItem.createWaypointItemId(
              OrderableItemType.viewingPointWaypoint,
              wp.id,
            ),
            type: OrderableItemType.viewingPointWaypoint,
            order: logisticsOrder++,
            waypointId: wp.id,
          ));
          break;
          
        case WaypointType.routePoint:
          // Route points are not part of the day plan ordering
          break;
      }
      
      // Track the first order value for each section
      if (sectionId != null && !sectionFirstOrder.containsKey(sectionId)) {
        sectionFirstOrder[sectionId] = wp.order;
      }
    }
    
    // Second pass: create section items with order based on first waypoint's order
    for (final wp in waypoints) {
      String? sectionId;
      OrderableItemType? itemType;
      String? sectionType;
      
      switch (wp.type) {
        case WaypointType.restaurant:
          final mealTime = wp.mealTime?.name ?? 'lunch';
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.restaurantSection, 
            mealTime,
          );
          itemType = OrderableItemType.restaurantSection;
          sectionType = mealTime;
          break;
          
        case WaypointType.activity:
          final activityTime = wp.activityTime?.name ?? 'afternoon';
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.activitySection,
            activityTime,
          );
          itemType = OrderableItemType.activitySection;
          sectionType = activityTime;
          break;
          
        case WaypointType.accommodation:
          sectionId = OrderableItem.createSectionId(
            OrderableItemType.accommodationSection,
            null,
          );
          itemType = OrderableItemType.accommodationSection;
          sectionType = null;
          break;
          
        default:
          break;
      }
      
      if (sectionId != null && itemType != null && !seenSections.contains(sectionId)) {
        seenSections.add(sectionId);
        // Use the first waypoint's order for this section, or default if not found
        final order = sectionFirstOrder[sectionId] ?? defaultOrder[sectionId] ?? currentOrder++;
        items.add(OrderableItem(
          id: sectionId,
          type: itemType,
          order: order,
          sectionType: sectionType,
        ));
      }
    }
    
    // Sort by order and reassign clean sequential orders
    items.sort((a, b) => a.order.compareTo(b.order));
    final reorderedItems = items.asMap().entries
        .map((e) => e.value.copyWith(order: e.key))
        .toList();
    
    return DayPlanOrderManager(dayNumber: dayNumber, items: reorderedItems);
  }
}

