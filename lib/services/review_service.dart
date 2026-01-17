import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/review_model.dart';
import 'package:waypoint/services/storage_service.dart';

enum ReviewSortOption {
  mostRecent,
  highestRated,
  lowestRated,
  mostHelpful,
}

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  /// Create a new review
  Future<Review> createReview({
    required String planId,
    required String tripId,
    required String versionId,
    required int rating,
    required String text,
    String? title,
    List<String>? tags,
    List<Uint8List>? photoBytes,
    DateTime? completedDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be authenticated to create a review');

    final reviewId = _firestore.collection('reviews').doc().id;
    final now = DateTime.now();

    // Upload photos if provided
    List<String> photoUrls = [];
    if (photoBytes != null && photoBytes.isNotEmpty) {
      for (int i = 0; i < photoBytes.length; i++) {
        try {
          final url = await _storageService.uploadReviewPhoto(
            reviewId: reviewId,
            userId: user.uid,
            photoBytes: photoBytes[i],
            index: i,
          );
          photoUrls.add(url);
        } catch (e) {
          debugPrint('Failed to upload review photo $i: $e');
        }
      }
    }

    final review = Review(
      id: reviewId,
      planId: planId,
      tripId: tripId,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
      userAvatar: user.photoURL,
      rating: rating,
      title: title,
      text: text,
      photos: photoUrls,
      completedDate: completedDate ?? now,
      versionId: versionId,
      tags: tags ?? [],
      createdAt: now,
      updatedAt: now,
    );

    // Save review to Firestore
    await _firestore.collection('reviews').doc(reviewId).set(review.toJson());

    // Update plan review stats
    await _updatePlanReviewStats(planId);

    return review;
  }

  /// Get reviews for a plan
  Future<List<Review>> getReviewsForPlan({
    required String planId,
    int limit = 10,
    ReviewSortOption sort = ReviewSortOption.mostRecent,
    String? searchQuery,
  }) async {
    Query query = _firestore
        .collection('reviews')
        .where('plan_id', isEqualTo: planId)
        .where('is_flagged', isEqualTo: false);

    // Apply sorting
    switch (sort) {
      case ReviewSortOption.mostRecent:
        query = query.orderBy('created_at', descending: true);
        break;
      case ReviewSortOption.highestRated:
        query = query.orderBy('rating', descending: true);
        break;
      case ReviewSortOption.lowestRated:
        query = query.orderBy('rating', descending: false);
        break;
      case ReviewSortOption.mostHelpful:
        query = query.orderBy('helpful_count', descending: true);
        break;
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    final reviews = snapshot.docs
        .map((doc) => Review.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Apply search filter if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      return reviews.where((review) {
        return review.text.toLowerCase().contains(lowerQuery) ||
            (review.title?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    return reviews;
  }

  /// Mark a review as helpful
  Future<void> markHelpful(String reviewId, String userId) async {
    final helpfulDoc = _firestore.collection('review_helpful').doc('${reviewId}_$userId');
    final exists = (await helpfulDoc.get()).exists;

    if (exists) {
      // Un-mark as helpful
      await helpfulDoc.delete();
      await _firestore.collection('reviews').doc(reviewId).update({
        'helpful_count': FieldValue.increment(-1),
      });
    } else {
      // Mark as helpful
      await helpfulDoc.set({
        'review_id': reviewId,
        'user_id': userId,
        'created_at': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('reviews').doc(reviewId).update({
        'helpful_count': FieldValue.increment(1),
      });
    }
  }

  /// Check if user marked review as helpful
  Future<bool> isMarkedHelpful(String reviewId, String userId) async {
    final doc = await _firestore.collection('review_helpful').doc('${reviewId}_$userId').get();
    return doc.exists;
  }

  /// Report a review
  Future<void> reportReview(String reviewId, String userId, String reason) async {
    await _firestore.collection('review_reports').add({
      'review_id': reviewId,
      'user_id': userId,
      'reason': reason,
      'created_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('reviews').doc(reviewId).update({
      'report_count': FieldValue.increment(1),
    });
  }

  /// Update plan review stats (called after creating/deleting review)
  Future<void> _updatePlanReviewStats(String planId) async {
    try {
      // Get all reviews for this plan
      final snapshot = await _firestore
          .collection('reviews')
          .where('plan_id', isEqualTo: planId)
          .where('is_flagged', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        // No reviews - set empty stats
        await _firestore.collection('plans').doc(planId).update({
          'review_stats': ReviewStats.empty().toJson(),
        });
        return;
      }

      // Calculate stats
      int totalReviews = snapshot.docs.length;
      int totalRating = 0;
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (final doc in snapshot.docs) {
        final review = Review.fromJson(doc.data());
        totalRating += review.rating;
        distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      }

      final stats = ReviewStats(
        averageRating: totalRating / totalReviews,
        totalReviews: totalReviews,
        ratingDistribution: distribution,
      );

      // Update plan document
      await _firestore.collection('plans').doc(planId).update({
        'review_stats': stats.toJson(),
      });
    } catch (e) {
      debugPrint('Failed to update plan review stats: $e');
    }
  }

  /// Check if user can review (must have completed trip)
  Future<bool> canUserReview(String userId, String planId) async {
    final tripSnapshot = await _firestore
        .collection('trips')
        .where('plan_id', isEqualTo: planId)
        .where('member_ids', arrayContains: userId)
        .where('status', isEqualTo: 'completed')
        .limit(1)
        .get();

    return tripSnapshot.docs.isNotEmpty;
  }

  /// Check if user already reviewed this plan
  Future<bool> hasUserReviewed(String userId, String planId) async {
    final reviewSnapshot = await _firestore
        .collection('reviews')
        .where('plan_id', isEqualTo: planId)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();

    return reviewSnapshot.docs.isNotEmpty;
  }
}
