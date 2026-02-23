import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/comment_model.dart';
import 'package:waypoint/services/notification_service.dart';
import 'package:waypoint/models/notification_model.dart';
import 'package:waypoint/services/user_service.dart';

/// Service for managing comments and questions on adventure plans
class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  /// Create a comment or question
  Future<Comment> createComment({
    required String planId,
    required String text,
    bool isQuestion = false,
    String? parentCommentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create a comment');
    }

    try {
      final commentId = _firestore.collection('plans').doc(planId).collection('comments').doc().id;
      final now = DateTime.now();

      final comment = Comment(
        id: commentId,
        planId: planId,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        userAvatar: user.photoURL,
        text: text,
        isQuestion: isQuestion,
        parentCommentId: parentCommentId,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .doc(commentId)
          .set(comment.toJson());

      debugPrint('[CommentService] Created comment $commentId for plan $planId');
      return comment;
    } catch (e) {
      debugPrint('[CommentService] Error creating comment: $e');
      rethrow;
    }
  }

  /// Get all comments for a plan
  Future<List<Comment>> getComments(String planId) async {
    try {
      final snapshot = await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Comment.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[CommentService] Error getting comments: $e');
      return [];
    }
  }

  /// Stream comments for a plan (real-time updates)
  Stream<List<Comment>> streamComments(String planId) {
    return _firestore
        .collection('plans')
        .doc(planId)
        .collection('comments')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson(doc.data()))
            .toList());
  }

  /// Create a reply to a comment (creator response)
  Future<void> createReply(String commentId, String text, String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to create a reply');
    }

    try {
      // Get the comment to verify it exists
      final commentDoc = await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      // Update the comment with creator response
      await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .doc(commentId)
          .update({
        'creator_response': text,
        'updated_at': FieldValue.serverTimestamp(),
      });

      debugPrint('[CommentService] Added reply to comment $commentId');

      // Create notification for the question asker
      try {
        final comment = Comment.fromJson(commentDoc.data()!);
        if (comment.isQuestion && comment.userId != user.uid) {
          final plan = await _firestore.collection('plans').doc(planId).get();
          final planName = plan.data()?['name'] as String? ?? 'adventure';
          final creator = await _userService.getUserById(user.uid);
          final creatorName = creator?.displayName ?? 'The creator';

          await _notificationService.createNotification(
            userId: comment.userId,
            type: NotificationType.comment_reply,
            relatedUserId: user.uid,
            relatedPlanId: planId,
            message: '$creatorName responded to your question about "$planName"',
          );
        }
      } catch (e) {
        // Don't fail the reply operation if notification fails
        debugPrint('[CommentService] Error creating reply notification: $e');
      }
    } catch (e) {
      debugPrint('[CommentService] Error creating reply: $e');
      rethrow;
    }
  }

  /// Delete a comment (only by creator or comment author)
  Future<void> deleteComment(String commentId, String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to delete a comment');
    }

    try {
      // Get the comment to check ownership
      final commentDoc = await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = Comment.fromJson(commentDoc.data()!);

      // Check if user is the comment author
      if (comment.userId != user.uid) {
        // Check if user is the plan creator (would need to fetch plan)
        // For now, only allow comment author to delete
        throw Exception('Only comment author can delete their comment');
      }

      await _firestore
          .collection('plans')
          .doc(planId)
          .collection('comments')
          .doc(commentId)
          .delete();

      debugPrint('[CommentService] Deleted comment $commentId');
    } catch (e) {
      debugPrint('[CommentService] Error deleting comment: $e');
      rethrow;
    }
  }

  /// Check if user is the plan creator (for allowing replies)
  Future<bool> isPlanCreator(String planId, String userId) async {
    try {
      final planDoc = await _firestore.collection('plans').doc(planId).get();
      if (!planDoc.exists) return false;
      final planData = planDoc.data()!;
      return planData['creator_id'] == userId;
    } catch (e) {
      debugPrint('[CommentService] Error checking plan creator: $e');
      return false;
    }
  }
}

