import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a comment or question on an adventure plan
class Comment {
  final String id;
  final String planId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final bool isQuestion; // True if this is a question (can be answered by creator)
  final String? parentCommentId; // For replies to comments
  final String? creatorResponse; // Creator's response to a question
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.planId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    this.isQuestion = false,
    this.parentCommentId,
    this.creatorResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      text: json['text'] as String,
      isQuestion: json['is_question'] as bool? ?? false,
      parentCommentId: json['parent_comment_id'] as String?,
      creatorResponse: json['creator_response'] as String?,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'user_id': userId,
      'user_name': userName,
      if (userAvatar != null) 'user_avatar': userAvatar,
      'text': text,
      'is_question': isQuestion,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      if (creatorResponse != null) 'creator_response': creatorResponse,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  Comment copyWith({
    String? id,
    String? planId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? text,
    bool? isQuestion,
    String? parentCommentId,
    String? creatorResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      isQuestion: isQuestion ?? this.isQuestion,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      creatorResponse: creatorResponse ?? this.creatorResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

