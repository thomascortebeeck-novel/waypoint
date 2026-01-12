import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/order_model.dart';

/// Service for managing user favorites with transaction-based toggling
class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Toggle favorite status for a plan (transaction-based)
  /// Returns true if the plan is now favorited, false if unfavorited
  Future<bool> toggleFavorite(String userId, String planId) async {
    try {
      final userFavoriteRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(planId);

      final planRef = _firestore.collection('plans').doc(planId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final favoriteDoc = await transaction.get(userFavoriteRef);
        final planDoc = await transaction.get(planRef);

        if (!planDoc.exists) {
          throw Exception('Plan not found');
        }

        final currentCount = (planDoc.data()?['favorite_count'] as num?)?.toInt() ?? 0;

        if (favoriteDoc.exists) {
          // Remove favorite
          transaction.delete(userFavoriteRef);
          transaction.update(planRef, {
            'favorite_count': currentCount > 0 ? currentCount - 1 : 0,
          });
          return false;
        } else {
          // Add favorite
          final favorite = FavoriteModel(
            planId: planId,
            savedAt: DateTime.now(),
          );
          transaction.set(userFavoriteRef, favorite.toJson());
          transaction.update(planRef, {
            'favorite_count': currentCount + 1,
          });
          return true;
        }
      });
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Check if a plan is favorited by the user
  Future<bool> isFavorited(String userId, String planId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(planId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }

  /// Get all favorited plan IDs for a user
  Future<List<String>> getFavoritePlanIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('saved_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  /// Stream favorite status for a specific plan
  Stream<bool> streamFavoriteStatus(String userId, String planId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(planId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Stream all favorited plan IDs for a user
  Stream<List<String>> streamFavoritePlanIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('saved_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}
