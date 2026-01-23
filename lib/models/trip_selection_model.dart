import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/plan_model.dart';

/// Booking status for a waypoint
enum WaypointBookingStatus {
  notNeeded,    // No booking required
  notBooked,    // Needs booking but not done yet
  booked,       // Booking confirmed
}

/// Selected waypoint with booking info
class SelectedWaypoint {
  final String id; // Waypoint ID for unique identification
  final String name;
  final String type; // accommodation type, meal type, or activity description
  final WaypointBookingStatus bookingStatus;
  final String? bookingConfirmation;
  final String? bookingLink;
  final double? cost;

  const SelectedWaypoint({
    required this.id,
    required this.name,
    required this.type,
    this.bookingStatus = WaypointBookingStatus.notNeeded,
    this.bookingConfirmation,
    this.bookingLink,
    this.cost,
  });

  factory SelectedWaypoint.fromAccommodation(AccommodationInfo accommodation) => SelectedWaypoint(
    id: accommodation.name, // Legacy fallback - use name as ID for old data model
    name: accommodation.name,
    type: accommodation.type,
    bookingStatus: accommodation.bookingLink != null 
        ? WaypointBookingStatus.notBooked 
        : WaypointBookingStatus.notNeeded,
    bookingLink: accommodation.bookingLink,
    cost: accommodation.cost,
  );

  factory SelectedWaypoint.fromRestaurant(RestaurantInfo restaurant) => SelectedWaypoint(
    id: restaurant.name, // Legacy fallback - use name as ID for old data model
    name: restaurant.name,
    type: restaurant.mealType.name,
    bookingStatus: restaurant.bookingLink != null 
        ? WaypointBookingStatus.notBooked 
        : WaypointBookingStatus.notNeeded,
    bookingLink: restaurant.bookingLink,
    cost: restaurant.cost,
  );

  factory SelectedWaypoint.fromActivity(ActivityInfo activity) => SelectedWaypoint(
    id: activity.name, // Legacy fallback - use name as ID for old data model
    name: activity.name,
    type: activity.description,
    bookingStatus: activity.bookingLink != null 
        ? WaypointBookingStatus.notBooked 
        : WaypointBookingStatus.notNeeded,
    bookingLink: activity.bookingLink,
    cost: activity.cost,
  );

  /// Create from RouteWaypoint (POI waypoint)
  factory SelectedWaypoint.fromRouteWaypoint(dynamic waypoint) {
    // Import RouteWaypoint dynamically to avoid circular imports
    final String id = waypoint.id as String;
    final String name = waypoint.name as String;
    final String type = waypoint.type.toString().split('.').last;
    final String? bookingUrl = waypoint.bookingComUrl ?? waypoint.airbnbPropertyUrl ?? waypoint.website;
    
    return SelectedWaypoint(
      id: id,
      name: name,
      type: type,
      bookingStatus: bookingUrl != null 
          ? WaypointBookingStatus.notBooked 
          : WaypointBookingStatus.notNeeded,
      bookingLink: bookingUrl,
    );
  }

  factory SelectedWaypoint.fromJson(Map<String, dynamic> json) => SelectedWaypoint(
    id: json['id'] as String? ?? json['name'] as String, // Fallback to name for legacy data
    name: json['name'] as String,
    type: json['type'] as String,
    bookingStatus: WaypointBookingStatus.values.firstWhere(
      (e) => e.name == json['booking_status'],
      orElse: () => WaypointBookingStatus.notNeeded,
    ),
    bookingConfirmation: json['booking_confirmation'] as String?,
    bookingLink: json['booking_link'] as String?,
    cost: (json['cost'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'booking_status': bookingStatus.name,
    if (bookingConfirmation != null) 'booking_confirmation': bookingConfirmation,
    if (bookingLink != null) 'booking_link': bookingLink,
    if (cost != null) 'cost': cost,
  };

  SelectedWaypoint copyWith({
    String? id,
    String? name,
    String? type,
    WaypointBookingStatus? bookingStatus,
    String? bookingConfirmation,
    String? bookingLink,
    double? cost,
  }) => SelectedWaypoint(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    bookingStatus: bookingStatus ?? this.bookingStatus,
    bookingConfirmation: bookingConfirmation ?? this.bookingConfirmation,
    bookingLink: bookingLink ?? this.bookingLink,
    cost: cost ?? this.cost,
  );
}

/// Creator's waypoint selections for a single day
/// Stored in: trips/{tripId}/selections/{dayNum}
class TripDaySelection {
  final String id; // 'day_1', 'day_2', etc.
  final String tripId;
  final int dayNum;
  /// Selected accommodation for the night (null if not staying overnight)
  final SelectedWaypoint? selectedAccommodation;
  /// Selected restaurants for the day (keyed by meal type: breakfast, lunch, dinner)
  final Map<String, SelectedWaypoint> selectedRestaurants;
  /// Selected activities for the day
  final List<SelectedWaypoint> selectedActivities;
  /// Optional notes from the creator
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripDaySelection({
    required this.id,
    required this.tripId,
    required this.dayNum,
    this.selectedAccommodation,
    this.selectedRestaurants = const {},
    this.selectedActivities = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate total estimated cost for the day
  double get totalCost {
    double total = 0;
    if (selectedAccommodation?.cost != null) {
      total += selectedAccommodation!.cost!;
    }
    for (final restaurant in selectedRestaurants.values) {
      if (restaurant.cost != null) total += restaurant.cost!;
    }
    for (final activity in selectedActivities) {
      if (activity.cost != null) total += activity.cost!;
    }
    return total;
  }

  /// Check if all bookable items are booked
  bool get allBooked {
    if (selectedAccommodation != null &&
        selectedAccommodation!.bookingStatus == WaypointBookingStatus.notBooked) {
      return false;
    }
    for (final restaurant in selectedRestaurants.values) {
      if (restaurant.bookingStatus == WaypointBookingStatus.notBooked) {
        return false;
      }
    }
    for (final activity in selectedActivities) {
      if (activity.bookingStatus == WaypointBookingStatus.notBooked) {
        return false;
      }
    }
    return true;
  }

  /// Get count of items that need booking
  int get pendingBookingsCount {
    int count = 0;
    if (selectedAccommodation?.bookingStatus == WaypointBookingStatus.notBooked) {
      count++;
    }
    for (final restaurant in selectedRestaurants.values) {
      if (restaurant.bookingStatus == WaypointBookingStatus.notBooked) count++;
    }
    for (final activity in selectedActivities) {
      if (activity.bookingStatus == WaypointBookingStatus.notBooked) count++;
    }
    return count;
  }

  factory TripDaySelection.fromJson(Map<String, dynamic> json) => TripDaySelection(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    dayNum: json['day_num'] as int,
    selectedAccommodation: json['selected_accommodation'] != null
        ? SelectedWaypoint.fromJson(json['selected_accommodation'] as Map<String, dynamic>)
        : null,
    selectedRestaurants: (json['selected_restaurants'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, SelectedWaypoint.fromJson(v as Map<String, dynamic>)),
    ) ?? {},
    selectedActivities: (json['selected_activities'] as List<dynamic>?)
        ?.map((a) => SelectedWaypoint.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    notes: json['notes'] as String?,
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'day_num': dayNum,
    if (selectedAccommodation != null) 'selected_accommodation': selectedAccommodation!.toJson(),
    'selected_restaurants': selectedRestaurants.map((k, v) => MapEntry(k, v.toJson())),
    'selected_activities': selectedActivities.map((a) => a.toJson()).toList(),
    if (notes != null) 'notes': notes,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  TripDaySelection copyWith({
    String? id,
    String? tripId,
    int? dayNum,
    SelectedWaypoint? selectedAccommodation,
    Map<String, SelectedWaypoint>? selectedRestaurants,
    List<SelectedWaypoint>? selectedActivities,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TripDaySelection(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    dayNum: dayNum ?? this.dayNum,
    selectedAccommodation: selectedAccommodation ?? this.selectedAccommodation,
    selectedRestaurants: selectedRestaurants ?? this.selectedRestaurants,
    selectedActivities: selectedActivities ?? this.selectedActivities,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Create an empty selection for a day
  factory TripDaySelection.empty({
    required String tripId,
    required int dayNum,
  }) {
    final now = DateTime.now();
    return TripDaySelection(
      id: 'day_$dayNum',
      tripId: tripId,
      dayNum: dayNum,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Individual member's packing checklist
/// Stored in: trips/{tripId}/member_packing/{memberId}
class MemberPacking {
  final String id; // Member's user ID
  final String tripId;
  final String memberId;
  /// Packing items: itemId -> checked
  final Map<String, bool> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemberPacking({
    required this.id,
    required this.tripId,
    required this.memberId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get count of checked items
  int get checkedCount => items.values.where((v) => v).length;

  /// Get total items count
  int get totalCount => items.length;

  /// Get progress percentage (0.0 - 1.0)
  double get progress => totalCount == 0 ? 0.0 : checkedCount / totalCount;

  /// Check if all items are packed
  bool get isComplete => totalCount > 0 && checkedCount == totalCount;

  factory MemberPacking.fromJson(Map<String, dynamic> json) => MemberPacking(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    memberId: json['member_id'] as String,
    items: (json['items'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)) ?? {},
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'member_id': memberId,
    'items': items,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  MemberPacking copyWith({
    String? id,
    String? tripId,
    String? memberId,
    Map<String, bool>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MemberPacking(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    memberId: memberId ?? this.memberId,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Create an empty packing list for a member
  factory MemberPacking.empty({
    required String tripId,
    required String memberId,
    List<String>? itemIds,
  }) {
    final now = DateTime.now();
    return MemberPacking(
      id: memberId,
      tripId: tripId,
      memberId: memberId,
      items: {for (final id in itemIds ?? []) id: false},
      createdAt: now,
      updatedAt: now,
    );
  }
}
