import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/trip_model.dart';

/// Lightweight trip metadata
/// Stored in: trips/{tripId}
class TripMeta {
  final String id;
  final String planId;
  final String ownerId;
  final List<String> memberIds;
  final String? title;
  final String? versionId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String inviteCode;
  final bool inviteEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripMeta({
    required this.id,
    required this.planId,
    required this.ownerId,
    required this.memberIds,
    this.title,
    this.versionId,
    this.startDate,
    this.endDate,
    this.isActive = true,
    String? inviteCode,
    this.inviteEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  }) : inviteCode = inviteCode ?? Trip.generateInviteCode();

  /// Check if a user is the trip owner
  bool isOwner(String userId) => ownerId == userId;

  /// Check if a user is a member of the trip
  bool isMember(String userId) => memberIds.contains(userId);

  factory TripMeta.fromJson(Map<String, dynamic> json) => TripMeta(
    id: json['id'] as String,
    planId: json['plan_id'] as String,
    ownerId: json['owner_id'] as String,
    memberIds: List<String>.from(json['member_ids'] ?? []),
    title: json['title'] as String?,
    versionId: json['version_id'] as String?,
    startDate: (json['start_date'] as Timestamp?)?.toDate(),
    endDate: (json['end_date'] as Timestamp?)?.toDate(),
    isActive: json['is_active'] as bool? ?? true,
    inviteCode: json['invite_code'] as String? ?? Trip.generateInviteCode(),
    inviteEnabled: json['invite_enabled'] as bool? ?? true,
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plan_id': planId,
    'owner_id': ownerId,
    'member_ids': memberIds,
    'title': title,
    'version_id': versionId,
    if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
    if (endDate != null) 'end_date': Timestamp.fromDate(endDate!),
    'is_active': isActive,
    'invite_code': inviteCode,
    'invite_enabled': inviteEnabled,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  TripMeta copyWith({
    String? id,
    String? planId,
    String? ownerId,
    List<String>? memberIds,
    String? title,
    String? versionId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? inviteCode,
    bool? inviteEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TripMeta(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    ownerId: ownerId ?? this.ownerId,
    memberIds: memberIds ?? this.memberIds,
    title: title ?? this.title,
    versionId: versionId ?? this.versionId,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isActive: isActive ?? this.isActive,
    inviteCode: inviteCode ?? this.inviteCode,
    inviteEnabled: inviteEnabled ?? this.inviteEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Convert from legacy Trip
  factory TripMeta.fromTrip(Trip trip) => TripMeta(
    id: trip.id,
    planId: trip.planId,
    ownerId: trip.ownerId,
    memberIds: trip.memberIds,
    title: trip.title,
    versionId: trip.versionId,
    startDate: trip.startDate,
    endDate: trip.endDate,
    isActive: trip.isActive,
    inviteCode: trip.inviteCode,
    inviteEnabled: trip.inviteEnabled,
    createdAt: trip.createdAt,
    updatedAt: trip.updatedAt,
  );

  /// Convert to legacy Trip
  Trip toTrip({Map<String, bool>? packingChecklist}) => Trip(
    id: id,
    planId: planId,
    ownerId: ownerId,
    memberIds: memberIds,
    title: title,
    versionId: versionId,
    startDate: startDate,
    endDate: endDate,
    packingChecklist: packingChecklist,
    isActive: isActive,
    inviteCode: inviteCode,
    inviteEnabled: inviteEnabled,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Packing checklist stored in subcollection
/// Stored in: trips/{tripId}/packing/{categoryId}
class TripPackingCategory {
  final String id;
  final String tripId;
  final String categoryName;
  final Map<String, bool> items; // itemId -> checked
  final DateTime createdAt;
  final DateTime updatedAt;

  TripPackingCategory({
    required this.id,
    required this.tripId,
    required this.categoryName,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripPackingCategory.fromJson(Map<String, dynamic> json) => TripPackingCategory(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    categoryName: json['category_name'] as String,
    items: (json['items'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)) ?? {},
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'category_name': categoryName,
    'items': items,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  TripPackingCategory copyWith({
    String? id,
    String? tripId,
    String? categoryName,
    Map<String, bool>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TripPackingCategory(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    categoryName: categoryName ?? this.categoryName,
    items: items ?? this.items,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Trip day progress tracking
/// Stored in: trips/{tripId}/days/{dayNum}
class TripDayProgress {
  final String id;
  final String tripId;
  final int dayNum;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<String> visitedWaypoints; // Waypoint IDs that have been visited
  final String? notes; // User notes for the day
  final List<String> photos; // User-uploaded photos
  final DateTime createdAt;
  final DateTime updatedAt;

  TripDayProgress({
    required this.id,
    required this.tripId,
    required this.dayNum,
    this.isCompleted = false,
    this.completedAt,
    this.visitedWaypoints = const [],
    this.notes,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripDayProgress.fromJson(Map<String, dynamic> json) => TripDayProgress(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    dayNum: json['day_num'] as int,
    isCompleted: json['is_completed'] as bool? ?? false,
    completedAt: (json['completed_at'] as Timestamp?)?.toDate(),
    visitedWaypoints: List<String>.from(json['visited_waypoints'] ?? []),
    notes: json['notes'] as String?,
    photos: List<String>.from(json['photos'] ?? []),
    createdAt: (json['created_at'] as Timestamp).toDate(),
    updatedAt: (json['updated_at'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'day_num': dayNum,
    'is_completed': isCompleted,
    if (completedAt != null) 'completed_at': Timestamp.fromDate(completedAt!),
    'visited_waypoints': visitedWaypoints,
    if (notes != null) 'notes': notes,
    'photos': photos,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  TripDayProgress copyWith({
    String? id,
    String? tripId,
    int? dayNum,
    bool? isCompleted,
    DateTime? completedAt,
    List<String>? visitedWaypoints,
    String? notes,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TripDayProgress(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    dayNum: dayNum ?? this.dayNum,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: completedAt ?? this.completedAt,
    visitedWaypoints: visitedWaypoints ?? this.visitedWaypoints,
    notes: notes ?? this.notes,
    photos: photos ?? this.photos,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// GPS tracking record
/// Stored in: trips/{tripId}/tracking/{recordId}
class TripTrackingRecord {
  final String id;
  final String tripId;
  final int dayNum;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;

  TripTrackingRecord({
    required this.id,
    required this.tripId,
    required this.dayNum,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    required this.timestamp,
  });

  factory TripTrackingRecord.fromJson(Map<String, dynamic> json) => TripTrackingRecord(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    dayNum: json['day_num'] as int,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    altitude: (json['altitude'] as num?)?.toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
    speed: (json['speed'] as num?)?.toDouble(),
    timestamp: (json['timestamp'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'day_num': dayNum,
    'latitude': latitude,
    'longitude': longitude,
    if (altitude != null) 'altitude': altitude,
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
