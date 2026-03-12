import 'package:cloud_firestore/cloud_firestore.dart';

/// Trip-specific insight (local tip) added by Insider/owner. Stored in trips/{tripId}/insights/{insightId}
class TripInsight {
  final String id;
  final String tripId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? createdBy;

  const TripInsight({
    required this.id,
    required this.tripId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.createdBy,
  });

  factory TripInsight.fromJson(Map<String, dynamic> json, String docId, String tripId) {
    final createdAt = json['created_at'];
    return TripInsight(
      id: docId,
      tripId: tripId,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: createdAt is Timestamp
          ? (createdAt as Timestamp).toDate()
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'created_at': Timestamp.fromDate(createdAt),
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  TripInsight copyWith({
    String? title,
    String? body,
  }) {
    return TripInsight(
      id: id,
      tripId: tripId,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}
