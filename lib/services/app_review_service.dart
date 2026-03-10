import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waypoint/models/app_review_model.dart';

class AppReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'app_reviews';

  /// Create an app review. Rating 1-5. [tripId] is optional (stored for context only).
  Future<AppReview> createAppReview({
    required int rating,
    String comment = '',
    String? tripId,
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
      createdAt: now,
    );
    await _firestore.collection(_collection).doc(id).set(review.toJson());
    return review;
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
