/// Trip-level override for a waypoint (date, time, status, price, alternatives, transport).
/// Stored in: trips/{tripId}/waypoint_overrides/{dayNum}_{waypointId}
class TripWaypointOverride {
  final String tripId;
  final int dayNum;
  final String waypointId;
  /// Day the waypoint is shown on (can differ from dayNum if moved). Defaults to dayNum.
  final int? targetDayNum;
  final String? actualStartTime; // HH:MM
  final String? status; // e.g. 'not_booked' | 'booked'
  final double? price; // actual cost paid by owner

  /// For pickOne: id of the chosen waypoint (stored on the primary waypoint's override).
  final String? selectedWaypointId;
  /// For addOn: owner explicitly skipped this alternative.
  final bool isDisabled;
  /// Alternative treated as standalone waypoint in this trip.
  final bool isPromoted;
  /// When isPromoted: display order in the day's active list (trip-only).
  final int? promotedOrder;
  /// Owner-defined transport mode for the segment TO this waypoint.
  final String? travelMode;
  /// Owner-overridden segment travel time (e.g. seconds).
  final int? travelTime;
  /// Owner-overridden segment distance (e.g. km).
  final double? travelDistance;

  const TripWaypointOverride({
    required this.tripId,
    required this.dayNum,
    required this.waypointId,
    this.targetDayNum,
    this.actualStartTime,
    this.status,
    this.price,
    this.selectedWaypointId,
    this.isDisabled = false,
    this.isPromoted = false,
    this.promotedOrder,
    this.travelMode,
    this.travelTime,
    this.travelDistance,
  });

  static String docId(int dayNum, String waypointId) => '${dayNum}_$waypointId';

  factory TripWaypointOverride.fromJson(Map<String, dynamic> json, String tripId) {
    final dayNum = json['day_num'] as int? ?? 0;
    final waypointId = json['waypoint_id'] as String? ?? '';
    return TripWaypointOverride(
      tripId: tripId,
      dayNum: dayNum,
      waypointId: waypointId,
      targetDayNum: json['target_day_num'] as int?,
      actualStartTime: json['actual_start_time'] as String?,
      status: json['status'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      selectedWaypointId: json['selected_waypoint_id'] as String?,
      isDisabled: json['is_disabled'] as bool? ?? false,
      isPromoted: json['is_promoted'] as bool? ?? false,
      promotedOrder: (json['promoted_order'] as num?)?.toInt(),
      travelMode: json['travel_mode'] as String?,
      travelTime: (json['travel_time'] as num?)?.toInt(),
      travelDistance: (json['travel_distance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'day_num': dayNum,
        'waypoint_id': waypointId,
        if (targetDayNum != null) 'target_day_num': targetDayNum,
        if (actualStartTime != null) 'actual_start_time': actualStartTime,
        if (status != null) 'status': status,
        if (price != null) 'price': price,
        if (selectedWaypointId != null) 'selected_waypoint_id': selectedWaypointId,
        if (isDisabled) 'is_disabled': isDisabled,
        if (isPromoted) 'is_promoted': isPromoted,
        if (promotedOrder != null) 'promoted_order': promotedOrder,
        if (travelMode != null) 'travel_mode': travelMode,
        if (travelTime != null) 'travel_time': travelTime,
        if (travelDistance != null) 'travel_distance': travelDistance,
      };

  TripWaypointOverride copyWith({
    String? tripId,
    int? dayNum,
    String? waypointId,
    int? targetDayNum,
    String? actualStartTime,
    String? status,
    double? price,
    String? selectedWaypointId,
    bool? isDisabled,
    bool? isPromoted,
    int? promotedOrder,
    String? travelMode,
    int? travelTime,
    double? travelDistance,
  }) =>
      TripWaypointOverride(
        tripId: tripId ?? this.tripId,
        dayNum: dayNum ?? this.dayNum,
        waypointId: waypointId ?? this.waypointId,
        targetDayNum: targetDayNum ?? this.targetDayNum,
        actualStartTime: actualStartTime ?? this.actualStartTime,
        status: status ?? this.status,
        price: price ?? this.price,
        selectedWaypointId: selectedWaypointId ?? this.selectedWaypointId,
        isDisabled: isDisabled ?? this.isDisabled,
        isPromoted: isPromoted ?? this.isPromoted,
        promotedOrder: promotedOrder ?? this.promotedOrder,
        travelMode: travelMode ?? this.travelMode,
        travelTime: travelTime ?? this.travelTime,
        travelDistance: travelDistance ?? this.travelDistance,
      );
}
