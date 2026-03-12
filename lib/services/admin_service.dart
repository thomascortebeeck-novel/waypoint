import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Dashboard stats for admin (plans, trips, users counts).
class AdminDashboardStats {
  final int planCount;
  final int tripCount;
  final int userCount;

  const AdminDashboardStats({
    required this.planCount,
    required this.tripCount,
    required this.userCount,
  });
}

/// Admin-only data: dashboard counts. Uses Firestore aggregation count when available,
/// otherwise get().docs.length (costly for large collections).
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches counts for plans, trips, users. Throws on permission or network error.
  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final plansSnap = await _firestore.collection('plans').get(const GetOptions(source: Source.server));
      final tripsSnap = await _firestore.collection('trips').get(const GetOptions(source: Source.server));
      final usersSnap = await _firestore.collection('users').get(const GetOptions(source: Source.server));
      return AdminDashboardStats(
        planCount: plansSnap.docs.length,
        tripCount: tripsSnap.docs.length,
        userCount: usersSnap.docs.length,
      );
    } catch (e) {
      debugPrint('[AdminService] getDashboardStats error: $e');
      rethrow;
    }
  }
}
