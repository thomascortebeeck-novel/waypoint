import 'package:cloud_firestore/cloud_firestore.dart';

/// A single check-in at a waypoint on a trip day.
/// Stored in: trips/{tripId}/check_ins (doc id = day_{n}_{waypointId}_{userId} for idempotency).
class CheckIn {
  final String id;
  final String tripId;
  final int dayNum;
  final String waypointId;
  final String userId;
  final DateTime createdAt;
  final String method; // 'location' | 'manual'
  final double? accuracyM;
  final double? distanceM;
  final String? photoUrl;
  final String? note;

  const CheckIn({
    required this.id,
    required this.tripId,
    required this.dayNum,
    required this.waypointId,
    required this.userId,
    required this.createdAt,
    required this.method,
    this.accuracyM,
    this.distanceM,
    this.photoUrl,
    this.note,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        dayNum: json['day_num'] as int,
        waypointId: json['waypoint_id'] as String,
        userId: json['user_id'] as String,
        createdAt: (json['created_at'] as Timestamp).toDate(),
        method: json['method'] as String? ?? 'manual',
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        distanceM: (json['distance_m'] as num?)?.toDouble(),
        photoUrl: json['photo_url'] as String?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'day_num': dayNum,
        'waypoint_id': waypointId,
        'user_id': userId,
        'created_at': Timestamp.fromDate(createdAt),
        'method': method,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (distanceM != null) 'distance_m': distanceM,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (note != null) 'note': note,
      };
}

/// Result of a check-in attempt.
class CheckInResult {
  final bool success;
  final int rank;
  final int totalCount;
  final String method;
  final double? distanceM;

  const CheckInResult({
    required this.success,
    required this.rank,
    required this.totalCount,
    required this.method,
    this.distanceM,
  });
}
