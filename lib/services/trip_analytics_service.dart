import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Records trip-level analytics for role dashboards (Navigator get-directions, Footprinter points, etc.).
class TripAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tripsCollection = 'trips';
  static const String _navigatorAnalyticsDoc = 'navigator_analytics';
  static const String _footprinterPointsDoc = 'footprinter_points';

  /// Record that "Get directions" was used (e.g. when user opens Google Maps to a waypoint).
  Future<void> recordGetDirections(String tripId, {int? dayNum}) async {
    try {
      final ref = _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_navigatorAnalyticsDoc)
          .doc('counts');
      await ref.set({
        'get_directions_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TripAnalyticsService.recordGetDirections failed: $e');
    }
  }

  /// Get get-directions count for Navigator dashboard.
  Future<int> getGetDirectionsCount(String tripId) async {
    try {
      final doc = await _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_navigatorAnalyticsDoc)
          .doc('counts')
          .get();
      final data = doc.data();
      if (data == null) return 0;
      final v = data['get_directions_count'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } catch (e) {
      debugPrint('TripAnalyticsService.getGetDirectionsCount failed: $e');
      return 0;
    }
  }

  /// Increment Footprinter green points (when Navigator chooses lower-CO2 transport than suggested).
  Future<void> incrementFootprinterPoints(String tripId) async {
    try {
      final ref = _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_footprinterPointsDoc)
          .doc('count');
      await ref.set({
        'count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TripAnalyticsService.incrementFootprinterPoints failed: $e');
    }
  }

  /// Get Footprinter green points count for dashboard.
  Future<int> getFootprinterPoints(String tripId) async {
    try {
      final doc = await _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_footprinterPointsDoc)
          .doc('count')
          .get();
      final data = doc.data();
      if (data == null) return 0;
      final v = data['count'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } catch (e) {
      debugPrint('TripAnalyticsService.getFootprinterPoints failed: $e');
      return 0;
    }
  }
}
