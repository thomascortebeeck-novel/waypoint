import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/trip_insight_model.dart';

/// Service for trip-specific insights (Insider/owner). Firestore: trips/{tripId}/insights/{insightId}
class TripInsightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tripsCollection = 'trips';
  static const String _insightsSubcollection = 'insights';

  Stream<List<TripInsight>> streamTripInsights(String tripId) {
    return _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_insightsSubcollection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TripInsight.fromJson(d.data(), d.id, tripId))
            .toList());
  }

  Future<List<TripInsight>> getTripInsights(String tripId) async {
    final snap = await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_insightsSubcollection)
        .orderBy('created_at', descending: true)
        .get();
    return snap.docs
        .map((d) => TripInsight.fromJson(d.data(), d.id, tripId))
        .toList();
  }

  Future<void> addTripInsight({
    required String tripId,
    required String title,
    required String body,
    String? createdBy,
  }) async {
    final col = _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_insightsSubcollection);
    final docRef = col.doc();
    final insight = TripInsight(
      id: docRef.id,
      tripId: tripId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    await docRef.set(insight.toJson());
  }

  Future<void> updateTripInsight({
    required String tripId,
    required String insightId,
    required String title,
    required String body,
  }) async {
    await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_insightsSubcollection)
        .doc(insightId)
        .update({'title': title, 'body': body});
  }

  Future<void> deleteTripInsight({required String tripId, required String insightId}) async {
    await _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_insightsSubcollection)
        .doc(insightId)
        .delete();
  }
}
