import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/notification_model.dart';

/// Service for managing user notifications
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a notification
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    String? relatedUserId,
    String? relatedPlanId,
    required String message,
  }) async {
    try {
      final notificationId = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc()
          .id;

      final notification = Notification(
        id: notificationId,
        userId: userId,
        type: type,
        relatedUserId: relatedUserId,
        relatedPlanId: relatedPlanId,
        message: message,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set(notification.toJson());

      debugPrint('[NotificationService] Created notification $notificationId for user $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error creating notification: $e');
      rethrow;
    }
  }

  /// Get all notifications for a user
  Future<List<Notification>> getNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => Notification.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('[NotificationService] Error getting notifications: $e');
      return [];
    }
  }

  /// Stream notifications for a user (real-time updates)
  Stream<List<Notification>> streamNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Notification.fromJson(doc.data()))
            .toList());
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('is_read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('[NotificationService] Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream unread notification count (real-time updates)
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'is_read': true,
      });
      debugPrint('[NotificationService] Marked notification $notificationId as read');
    } catch (e) {
      debugPrint('[NotificationService] Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
      debugPrint('[NotificationService] Marked all notifications as read for user $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('[NotificationService] Deleted notification $notificationId');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
      rethrow;
    }
  }
}

