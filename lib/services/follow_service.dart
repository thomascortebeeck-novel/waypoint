import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/services/user_service.dart';
import 'package:waypoint/services/notification_service.dart';
import 'package:waypoint/models/notification_model.dart';

/// Service for managing creator following relationships
class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  /// Follow a creator
  /// Updates both user's following list and creator's followers list
  Future<void> followCreator(String userId, String creatorId) async {
    if (userId == creatorId) {
      throw Exception('Cannot follow yourself');
    }

    try {
      final batch = _firestore.batch();

      // Get current user document
      final userDoc = _firestore.collection('users').doc(userId);
      final userSnapshot = await userDoc.get();
      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }

      // Get creator document
      final creatorDoc = _firestore.collection('users').doc(creatorId);
      final creatorSnapshot = await creatorDoc.get();
      if (!creatorSnapshot.exists) {
        throw Exception('Creator not found');
      }

      final userData = userSnapshot.data()!;
      final creatorData = creatorSnapshot.data()!;

      // Get current lists
      final followingIds = List<String>.from(userData['following_ids'] ?? []);
      final followerIds = List<String>.from(creatorData['follower_ids'] ?? []);

      // Check if already following
      if (followingIds.contains(creatorId)) {
        return; // Already following, no-op
      }

      // Add to lists
      followingIds.add(creatorId);
      followerIds.add(userId);

      // Update user document
      batch.update(userDoc, {
        'following_ids': followingIds,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update creator document
      batch.update(creatorDoc, {
        'follower_ids': followerIds,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Create subcollection documents for easier querying
      batch.set(
        userDoc.collection('following').doc(creatorId),
        {
          'creator_id': creatorId,
          'created_at': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        creatorDoc.collection('followers').doc(userId),
        {
          'user_id': userId,
          'created_at': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      debugPrint('[FollowService] User $userId now following creator $creatorId');

      // Create notification for creator
      try {
        final creator = await _userService.getUserById(creatorId);
        if (creator != null) {
          final follower = await _userService.getUserById(userId);
          final followerName = follower?.displayName ?? 'Someone';
          await _notificationService.createNotification(
            userId: creatorId,
            type: NotificationType.follow,
            relatedUserId: userId,
            message: '$followerName started following you',
          );
        }
      } catch (e) {
        // Don't fail the follow operation if notification fails
        debugPrint('[FollowService] Error creating follow notification: $e');
      }
    } catch (e) {
      debugPrint('[FollowService] Error following creator: $e');
      rethrow;
    }
  }

  /// Unfollow a creator
  /// Removes from both user's following list and creator's followers list
  Future<void> unfollowCreator(String userId, String creatorId) async {
    try {
      final batch = _firestore.batch();

      // Get current user document
      final userDoc = _firestore.collection('users').doc(userId);
      final userSnapshot = await userDoc.get();
      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }

      // Get creator document
      final creatorDoc = _firestore.collection('users').doc(creatorId);
      final creatorSnapshot = await creatorDoc.get();
      if (!creatorSnapshot.exists) {
        throw Exception('Creator not found');
      }

      final userData = userSnapshot.data()!;
      final creatorData = creatorSnapshot.data()!;

      // Get current lists
      final followingIds = List<String>.from(userData['following_ids'] ?? []);
      final followerIds = List<String>.from(creatorData['follower_ids'] ?? []);

      // Check if not following
      if (!followingIds.contains(creatorId)) {
        return; // Not following, no-op
      }

      // Remove from lists
      followingIds.remove(creatorId);
      followerIds.remove(userId);

      // Update user document
      batch.update(userDoc, {
        'following_ids': followingIds,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update creator document
      batch.update(creatorDoc, {
        'follower_ids': followerIds,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Delete subcollection documents
      batch.delete(userDoc.collection('following').doc(creatorId));
      batch.delete(creatorDoc.collection('followers').doc(userId));

      await batch.commit();
      debugPrint('[FollowService] User $userId unfollowed creator $creatorId');
    } catch (e) {
      debugPrint('[FollowService] Error unfollowing creator: $e');
      rethrow;
    }
  }

  /// Get list of creator IDs that a user follows
  Future<List<String>> getFollowing(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return [];
      }
      final data = userDoc.data()!;
      return List<String>.from(data['following_ids'] ?? []);
    } catch (e) {
      debugPrint('[FollowService] Error getting following: $e');
      return [];
    }
  }

  /// Get list of user IDs following a creator
  Future<List<String>> getFollowers(String creatorId) async {
    try {
      final creatorDoc = await _firestore.collection('users').doc(creatorId).get();
      if (!creatorDoc.exists) {
        return [];
      }
      final data = creatorDoc.data()!;
      return List<String>.from(data['follower_ids'] ?? []);
    } catch (e) {
      debugPrint('[FollowService] Error getting followers: $e');
      return [];
    }
  }

  /// Check if a user is following a creator
  Future<bool> isFollowing(String userId, String creatorId) async {
    try {
      final following = await getFollowing(userId);
      return following.contains(creatorId);
    } catch (e) {
      debugPrint('[FollowService] Error checking follow status: $e');
      return false;
    }
  }

  /// Stream of following list for a user
  Stream<List<String>> streamFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data()!;
      return List<String>.from(data['following_ids'] ?? []);
    });
  }

  /// Stream of followers list for a creator
  Stream<List<String>> streamFollowers(String creatorId) {
    return _firestore
        .collection('users')
        .doc(creatorId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data()!;
      return List<String>.from(data['follower_ids'] ?? []);
    });
  }
}

