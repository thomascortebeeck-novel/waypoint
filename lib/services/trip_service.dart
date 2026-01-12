import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/services/user_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'trips';
  final UserService _userService = UserService();

  Future<String> createTrip({
    required String planId,
    required String ownerId,
    List<String> memberIds = const [],
    String? title,
  }) async {
    try {
      // Validate owner owns the plan
      final owner = await _userService.getUserById(ownerId);
      if (owner == null || !owner.purchasedPlanIds.contains(planId)) {
        throw Exception('Owner must own the plan to create a trip');
      }

      // Ensure all members own the plan
      for (final uid in memberIds) {
        final u = await _userService.getUserById(uid);
        if (u == null || !u.purchasedPlanIds.contains(planId)) {
          throw Exception('All members must own the plan to join the trip');
        }
      }

      final doc = _firestore.collection(_collection).doc();
      final now = DateTime.now();
      final trip = Trip(
        id: doc.id,
        planId: planId,
        ownerId: ownerId,
        memberIds: {ownerId, ...memberIds}.toList(),
        title: title,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await doc.set(trip.toJson());
      return doc.id;
    } catch (e) {
      debugPrint('Error creating trip: $e');
      rethrow;
    }
  }

  Future<void> addMember({required String tripId, required String userId, required String planId}) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user == null || !user.purchasedPlanIds.contains(planId)) {
        throw Exception('User must own the plan to join the trip');
      }
      await _firestore.collection(_collection).doc(tripId).update({
        'member_ids': FieldValue.arrayUnion([userId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error adding member: $e');
      rethrow;
    }
  }

  Future<void> removeMember({required String tripId, required String userId}) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'member_ids': FieldValue.arrayRemove([userId]),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  Stream<List<Trip>> streamTripsForUser(String userId) {
    // Avoid composite index requirement by sorting client-side
    return _firestore
        .collection(_collection)
        .where('member_ids', arrayContains: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => Trip.fromJson(d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<Trip>> streamTripsForUserPlan(String userId, String planId) {
    // Avoid composite index requirement by querying only member_ids and filtering client-side
    return _firestore
        .collection(_collection)
        .where('member_ids', arrayContains: userId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Trip.fromJson(d.data()))
              .where((t) => t.planId == planId) // Filter by planId client-side
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<List<Trip>> getTripsForUserPlan(String userId, String planId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('member_ids', arrayContains: userId)
          .where('plan_id', isEqualTo: planId)
          .orderBy('created_at', descending: true)
          .get();
      return snap.docs.map((d) => Trip.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error fetching trips for user/plan: $e');
      return [];
    }
  }

  Future<Trip?> getTripById(String tripId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(tripId).get();
      if (!doc.exists) return null;
      return Trip.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting trip: $e');
      return null;
    }
  }

  Future<Trip> getOrCreateTripForUserPlan({
    required String userId,
    required String planId,
    String? title,
  }) async {
    try {
      final existing = await getTripsForUserPlan(userId, planId);
      if (existing.isNotEmpty) return existing.first;
      final id = await createTrip(planId: planId, ownerId: userId, title: title);
      final trip = await getTripById(id);
      if (trip == null) throw Exception('Failed to create trip');
      return trip;
    } catch (e) {
      debugPrint('getOrCreateTripForUserPlan error: $e');
      rethrow;
    }
  }

  Future<void> updateTripDates({required String tripId, required DateTime start, required DateTime end}) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'start_date': Timestamp.fromDate(start),
        'end_date': Timestamp.fromDate(end),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating trip dates: $e');
      rethrow;
    }
  }

  Future<void> initializePackingChecklist({required String tripId, required List<String> items}) async {
    try {
      final map = {for (final i in items) i: false};
      await _firestore.collection(_collection).doc(tripId).update({
        'packing_checklist': map,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error initializing packing checklist: $e');
      rethrow;
    }
  }

  Future<void> togglePackingItem({required String tripId, required String item, required bool checked}) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'packing_checklist.$item': checked,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error toggling packing item: $e');
      rethrow;
    }
  }

   Future<void> setTripVersionAndDates({
    required String tripId,
    required String versionId,
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      final data = <String, dynamic>{
        'version_id': versionId,
        'updated_at': Timestamp.now(),
      };
      if (start != null) data['start_date'] = Timestamp.fromDate(start);
      if (end != null) data['end_date'] = Timestamp.fromDate(end);
      await _firestore.collection(_collection).doc(tripId).update(data);
    } catch (e) {
      debugPrint('Error updating trip version/dates: $e');
      rethrow;
    }
  }

  /// Update trip title
  Future<void> updateTripTitle({required String tripId, required String title}) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'title': title,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating trip title: $e');
      rethrow;
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_collection).doc(tripId).delete();
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      rethrow;
    }
  }
}
