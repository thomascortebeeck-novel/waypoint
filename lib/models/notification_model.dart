import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification types
enum NotificationType {
  follow,        // Someone followed the user (for creators)
  comment_reply, // Creator responded to a question
}

/// Represents a notification for a user
class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String? relatedUserId; // User who performed the action (follower, creator)
  final String? relatedPlanId; // Plan related to the notification
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    this.relatedUserId,
    this.relatedPlanId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.follow,
      ),
      relatedUserId: json['related_user_id'] as String?,
      relatedPlanId: json['related_plan_id'] as String?,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: (json['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      if (relatedUserId != null) 'related_user_id': relatedUserId,
      if (relatedPlanId != null) 'related_plan_id': relatedPlanId,
      'message': message,
      'is_read': isRead,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  Notification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? relatedUserId,
    String? relatedPlanId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      relatedPlanId: relatedPlanId ?? this.relatedPlanId,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

