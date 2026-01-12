import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'users';

  /// Create a new user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).set(user.toJson());
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  /// Get a user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Update user
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).update(
        user.copyWith(updatedAt: DateTime.now()).toJson(),
      );
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  /// Add purchased plan to user
  Future<void> addPurchasedPlan(String userId, String planId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'purchased_plan_ids': FieldValue.arrayUnion([planId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding purchased plan: $e');
      rethrow;
    }
  }

  /// Add created plan to user
  Future<void> addCreatedPlan(String userId, String planId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'created_plan_ids': FieldValue.arrayUnion([planId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding created plan: $e');
      rethrow;
    }
  }

  /// Remove created plan from user
  Future<void> removeCreatedPlan(String userId, String planId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'created_plan_ids': FieldValue.arrayRemove([planId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error removing created plan: $e');
      rethrow;
    }
  }

  /// Add invited plan to user
  Future<void> addInvitedPlan(String userId, String planId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'invited_plan_ids': FieldValue.arrayUnion([planId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding invited plan: $e');
      rethrow;
    }
  }

  /// Stream user updates
  Stream<UserModel?> streamUser(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromJson(doc.data()!) : null);
  }
}
