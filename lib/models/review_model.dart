import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user review for a plan
class Review {
  final String id;
  final String planId;
  final String tripId;
  final String userId;
  final String userName;
  final String? userAvatar;
  
  // Rating
  final int rating; // 1-5 stars
  
  // Review content
  final String? title;
  final String text;
  final List<String> photos;
  
  // Trip details
  final DateTime completedDate;
  final String versionId;
  final String? activityType;
  
  // Tags/badges
  final List<String> tags;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Moderation
  final bool isVerified;
  final bool isFlagged;
  final String? flagReason;
  
  // Engagement
  final int helpfulCount;
  final int reportCount;

  Review({
    required this.id,
    required this.planId,
    required this.tripId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    this.title,
    required this.text,
    this.photos = const [],
    required this.completedDate,
    required this.versionId,
    this.activityType,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.isFlagged = false,
    this.flagReason,
    this.helpfulCount = 0,
    this.reportCount = 0,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      tripId: json['trip_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      rating: json['rating'] as int,
      title: json['title'] as String?,
      text: json['text'] as String,
      photos: List<String>.from(json['photos'] ?? []),
      completedDate: (json['completed_date'] as Timestamp).toDate(),
      versionId: json['version_id'] as String,
      activityType: json['activity_type'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
      isVerified: json['is_verified'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagReason: json['flag_reason'] as String?,
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'trip_id': tripId,
      'user_id': userId,
      'user_name': userName,
      if (userAvatar != null) 'user_avatar': userAvatar,
      'rating': rating,
      if (title != null) 'title': title,
      'text': text,
      'photos': photos,
      'completed_date': Timestamp.fromDate(completedDate),
      'version_id': versionId,
      if (activityType != null) 'activity_type': activityType,
      'tags': tags,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'is_verified': isVerified,
      'is_flagged': isFlagged,
      if (flagReason != null) 'flag_reason': flagReason,
      'helpful_count': helpfulCount,
      'report_count': reportCount,
    };
  }

  Review copyWith({
    String? id,
    String? planId,
    String? tripId,
    String? userId,
    String? userName,
    String? userAvatar,
    int? rating,
    String? title,
    String? text,
    List<String>? photos,
    DateTime? completedDate,
    String? versionId,
    String? activityType,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
    bool? isFlagged,
    String? flagReason,
    int? helpfulCount,
    int? reportCount,
  }) {
    return Review(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      text: text ?? this.text,
      photos: photos ?? this.photos,
      completedDate: completedDate ?? this.completedDate,
      versionId: versionId ?? this.versionId,
      activityType: activityType ?? this.activityType,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      reportCount: reportCount ?? this.reportCount,
    );
  }
}

/// Review statistics stored on Plan document
class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // rating -> count

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory ReviewStats.empty() {
    return ReviewStats(
      averageRating: 0.0,
      totalReviews: 0,
      ratingDistribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    );
  }

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      ratingDistribution: (json['rating_distribution'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), (v as num).toInt())) ??
          {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'rating_distribution': ratingDistribution.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  /// Get percentage for a specific rating
  double getPercentage(int rating) {
    if (totalReviews == 0) return 0.0;
    final count = ratingDistribution[rating] ?? 0;
    return (count / totalReviews) * 100;
  }
}
