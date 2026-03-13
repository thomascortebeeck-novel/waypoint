import 'package:cloud_firestore/cloud_firestore.dart';

/// User contact/support request. Stored in Firestore collection `contact_requests`.
class ContactRequest {
  final String id;
  final String userId;
  final String? userEmail;
  final String name;
  final String? relatedPlanId;
  final String? relatedTripId;
  final String description;
  final String? screenshotUrl;
  final DateTime createdAt;

  const ContactRequest({
    required this.id,
    required this.userId,
    this.userEmail,
    required this.name,
    this.relatedPlanId,
    this.relatedTripId,
    required this.description,
    this.screenshotUrl,
    required this.createdAt,
  });

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    return ContactRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String?,
      name: json['name'] as String,
      relatedPlanId: json['related_plan_id'] as String?,
      relatedTripId: json['related_trip_id'] as String?,
      description: json['description'] as String,
      screenshotUrl: json['screenshot_url'] as String?,
      createdAt: (json['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (userEmail != null && userEmail!.isNotEmpty) 'user_email': userEmail,
      'name': name,
      if (relatedPlanId != null && relatedPlanId!.isNotEmpty) 'related_plan_id': relatedPlanId,
      if (relatedTripId != null && relatedTripId!.isNotEmpty) 'related_trip_id': relatedTripId,
      'description': description,
      if (screenshotUrl != null && screenshotUrl!.isNotEmpty) 'screenshot_url': screenshotUrl,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
