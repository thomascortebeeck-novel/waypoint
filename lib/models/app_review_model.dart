import 'package:cloud_firestore/cloud_firestore.dart';

/// User review of the Waypoint app (how they liked using the app).
/// Stored in Firestore collection `app_reviews`.
///
/// [tripId] is stored for context only (e.g. which trip led to this feedback;
/// future admin/analytics). Not used for querying in v1.
class AppReview {
  final String id;
  final String userId;
  /// 1-5 stars.
  final int rating;
  /// Optional comment; may be empty.
  final String comment;
  /// Optional; for context (which trip led to this feedback). Not queried in v1.
  final String? tripId;
  final DateTime createdAt;

  const AppReview({
    required this.id,
    required this.userId,
    required this.rating,
    this.comment = '',
    this.tripId,
    required this.createdAt,
  });

  factory AppReview.fromJson(Map<String, dynamic> json) {
    return AppReview(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String? ?? '',
      tripId: json['trip_id'] as String?,
      createdAt: (json['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      if (tripId != null && tripId!.isNotEmpty) 'trip_id': tripId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
