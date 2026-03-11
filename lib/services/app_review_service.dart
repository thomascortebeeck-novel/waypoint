import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/models/app_review_model.dart';

class AppReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'app_reviews';

  /// Create an app review. Rating 1-5. [tripId] is optional (stored for context only).
  /// [allowShowOnWebsite] should be true only when rating >= 4 and comment is not empty and user consented.
  Future<AppReview> createAppReview({
    required int rating,
    String comment = '',
    String? tripId,
    bool allowShowOnWebsite = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be authenticated to create an app review');

    final id = _firestore.collection(_collection).doc().id;
    final now = DateTime.now();
    final review = AppReview(
      id: id,
      userId: user.uid,
      rating: rating,
      comment: comment,
      tripId: tripId,
      allowShowOnWebsite: allowShowOnWebsite,
      createdAt: now,
    );
    await _firestore.collection(_collection).doc(id).set(review.toJson());
    return review;
  }

  /// Latest app reviews allowed for website display (rating 4 or 5, has description, allowShowOnWebsite true).
  /// Ordered by createdAt descending.
  Future<List<AppReview>> getLatestReviewsForWebsite({int limit = 20}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('allow_show_on_website', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((d) => AppReview.fromJson(d.data()))
        .where((r) => r.rating >= 4 && r.comment.trim().isNotEmpty)
        .toList();
  }

  /// Stream of latest app reviews for website (same filter as [getLatestReviewsForWebsite]).
  Stream<List<AppReview>> streamLatestReviewsForWebsite({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('allow_show_on_website', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AppReview.fromJson(d.data()))
            .where((r) => r.rating >= 4 && r.comment.trim().isNotEmpty)
            .toList());
  }

  /// Whether the user has already submitted an app review (any time).
  /// Used to avoid prompting again if desired; not required for the trip review flow.
  Future<bool> hasUserSubmittedAppReview(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
