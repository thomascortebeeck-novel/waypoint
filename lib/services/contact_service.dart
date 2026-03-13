import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/contact_request_model.dart';

/// Service for contact/support requests. Firestore collection: `contact_requests`.
class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'contact_requests';

  /// Create a contact request. If [requestId] is provided (e.g. after uploading a screenshot to that path), that doc id is used; otherwise one is generated.
  Future<void> createContactRequest({
    required String userId,
    String? userEmail,
    required String name,
    String? relatedPlanId,
    String? relatedTripId,
    required String description,
    String? screenshotUrl,
    String? requestId,
  }) async {
    final doc = requestId != null
        ? _firestore.collection(_collection).doc(requestId)
        : _firestore.collection(_collection).doc();
    final request = ContactRequest(
      id: doc.id,
      userId: userId,
      userEmail: userEmail,
      name: name,
      relatedPlanId: relatedPlanId,
      relatedTripId: relatedTripId,
      description: description,
      screenshotUrl: screenshotUrl,
      createdAt: DateTime.now(),
    );
    await doc.set(request.toJson());
  }

  /// Stream all contact requests for admin (newest first).
  Stream<List<ContactRequest>> streamContactRequests() {
    return _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((d) => ContactRequest.fromJson(d.data()))
          .toList();
    });
  }
}
