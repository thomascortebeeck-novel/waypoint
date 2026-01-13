import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_meta_model.dart';
import 'package:waypoint/services/user_service.dart';

/// Service for managing trips with hybrid subcollection architecture
/// 
/// Structure:
/// - trips/{tripId} - TripMeta (lightweight trip metadata)
/// - trips/{tripId}/packing/{categoryId} - TripPackingCategory (packing checklist per category)
/// - trips/{tripId}/days/{dayNum} - TripDayProgress (day completion/notes/photos)
/// - trips/{tripId}/tracking/{recordId} - TripTrackingRecord (GPS tracking points)
class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'trips';
  static const String _packingCollection = 'packing';
  static const String _daysCollection = 'days';
  static const String _trackingCollection = 'tracking';
  final UserService _userService = UserService();

  // ============================================================================
  // TRIP METADATA OPERATIONS
  // ============================================================================

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
    return _firestore
        .collection(_collection)
        .where('member_ids', arrayContains: userId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Trip.fromJson(d.data()))
              .where((t) => t.planId == planId)
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

  /// Delete a trip and all subcollections
  Future<void> deleteTrip(String tripId) async {
    try {
      // Delete packing categories
      final packingSnap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_packingCollection)
          .get();
      for (final doc in packingSnap.docs) {
        await doc.reference.delete();
      }
      
      // Delete day progress
      final daysSnap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .get();
      for (final doc in daysSnap.docs) {
        await doc.reference.delete();
      }
      
      // Delete tracking records
      final trackingSnap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_trackingCollection)
          .get();
      for (final doc in trackingSnap.docs) {
        await doc.reference.delete();
      }
      
      // Delete main document
      await _firestore.collection(_collection).doc(tripId).delete();
    } catch (e) {
      debugPrint('Error deleting trip: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PACKING CHECKLIST OPERATIONS (Subcollection)
  // ============================================================================

  /// Initialize packing checklist (legacy - flat map)
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

  /// Toggle packing item (legacy - flat map)
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

  /// Initialize packing categories (subcollection - for large packing lists)
  Future<void> initializePackingCategories({
    required String tripId,
    required Map<String, List<String>> categories, // categoryName -> itemIds
  }) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final entry in categories.entries) {
        final categoryName = entry.key;
        final itemIds = entry.value;
        final categoryId = categoryName.toLowerCase().replaceAll(' ', '_');
        
        final category = TripPackingCategory(
          id: categoryId,
          tripId: tripId,
          categoryName: categoryName,
          items: {for (final id in itemIds) id: false},
          createdAt: now,
          updatedAt: now,
        );
        
        final ref = _firestore
            .collection(_collection)
            .doc(tripId)
            .collection(_packingCollection)
            .doc(categoryId);
        batch.set(ref, category.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error initializing packing categories: $e');
      rethrow;
    }
  }

  /// Get all packing categories for a trip
  Future<List<TripPackingCategory>> getPackingCategories(String tripId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_packingCollection)
          .get();
      return snap.docs.map((d) => TripPackingCategory.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting packing categories: $e');
      return [];
    }
  }

  /// Toggle item in a packing category
  Future<void> togglePackingCategoryItem({
    required String tripId,
    required String categoryId,
    required String itemId,
    required bool checked,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_packingCollection)
          .doc(categoryId)
          .update({
            'items.$itemId': checked,
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error toggling packing category item: $e');
      rethrow;
    }
  }

  /// Stream packing categories
  Stream<List<TripPackingCategory>> streamPackingCategories(String tripId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_packingCollection)
        .snapshots()
        .map((s) => s.docs.map((d) => TripPackingCategory.fromJson(d.data())).toList());
  }

  // ============================================================================
  // DAY PROGRESS OPERATIONS (Subcollection)
  // ============================================================================

  /// Get day progress for a trip
  Future<List<TripDayProgress>> getDayProgress(String tripId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .orderBy('day_num')
          .get();
      return snap.docs.map((d) => TripDayProgress.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting day progress: $e');
      return [];
    }
  }

  /// Get single day progress
  Future<TripDayProgress?> getDayProgressByNum(String tripId, int dayNum) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .doc('day_$dayNum')
          .get();
      if (!doc.exists) return null;
      return TripDayProgress.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting day progress: $e');
      return null;
    }
  }

  /// Initialize day progress for a trip
  Future<void> initializeDayProgress({required String tripId, required int totalDays}) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (var i = 1; i <= totalDays; i++) {
        final progress = TripDayProgress(
          id: 'day_$i',
          tripId: tripId,
          dayNum: i,
          createdAt: now,
          updatedAt: now,
        );
        
        final ref = _firestore
            .collection(_collection)
            .doc(tripId)
            .collection(_daysCollection)
            .doc('day_$i');
        batch.set(ref, progress.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error initializing day progress: $e');
      rethrow;
    }
  }

  /// Mark day as completed
  Future<void> markDayCompleted({required String tripId, required int dayNum, required bool completed}) async {
    try {
      final data = <String, dynamic>{
        'is_completed': completed,
        'updated_at': Timestamp.now(),
      };
      if (completed) {
        data['completed_at'] = Timestamp.now();
      }
      
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .doc('day_$dayNum')
          .update(data);
    } catch (e) {
      debugPrint('Error marking day completed: $e');
      rethrow;
    }
  }

  /// Add visited waypoint
  Future<void> addVisitedWaypoint({required String tripId, required int dayNum, required String waypointId}) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .doc('day_$dayNum')
          .update({
            'visited_waypoints': FieldValue.arrayUnion([waypointId]),
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error adding visited waypoint: $e');
      rethrow;
    }
  }

  /// Update day notes
  Future<void> updateDayNotes({required String tripId, required int dayNum, required String notes}) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .doc('day_$dayNum')
          .update({
            'notes': notes,
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error updating day notes: $e');
      rethrow;
    }
  }

  /// Add photo to day
  Future<void> addDayPhoto({required String tripId, required int dayNum, required String photoUrl}) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_daysCollection)
          .doc('day_$dayNum')
          .update({
            'photos': FieldValue.arrayUnion([photoUrl]),
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error adding day photo: $e');
      rethrow;
    }
  }

  /// Stream day progress
  Stream<List<TripDayProgress>> streamDayProgress(String tripId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_daysCollection)
        .orderBy('day_num')
        .snapshots()
        .map((s) => s.docs.map((d) => TripDayProgress.fromJson(d.data())).toList());
  }

  // ============================================================================
  // GPS TRACKING OPERATIONS (Subcollection)
  // ============================================================================

  /// Add tracking record
  Future<void> addTrackingRecord(TripTrackingRecord record) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(record.tripId)
          .collection(_trackingCollection)
          .doc(record.id)
          .set(record.toJson());
    } catch (e) {
      debugPrint('Error adding tracking record: $e');
      rethrow;
    }
  }

  /// Add batch of tracking records (for efficiency)
  Future<void> addTrackingRecords(List<TripTrackingRecord> records) async {
    if (records.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final record in records) {
        final ref = _firestore
            .collection(_collection)
            .doc(record.tripId)
            .collection(_trackingCollection)
            .doc(record.id);
        batch.set(ref, record.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error adding tracking records: $e');
      rethrow;
    }
  }

  /// Get tracking records for a day
  Future<List<TripTrackingRecord>> getTrackingRecords(String tripId, int dayNum) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_trackingCollection)
          .where('day_num', isEqualTo: dayNum)
          .orderBy('timestamp')
          .get();
      return snap.docs.map((d) => TripTrackingRecord.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting tracking records: $e');
      return [];
    }
  }

  /// Get all tracking records for a trip
  Future<List<TripTrackingRecord>> getAllTrackingRecords(String tripId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_trackingCollection)
          .orderBy('timestamp')
          .get();
      return snap.docs.map((d) => TripTrackingRecord.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting all tracking records: $e');
      return [];
    }
  }

  /// Stream tracking records for a day
  Stream<List<TripTrackingRecord>> streamTrackingRecords(String tripId, int dayNum) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_trackingCollection)
        .where('day_num', isEqualTo: dayNum)
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map((d) => TripTrackingRecord.fromJson(d.data())).toList());
  }

  // ============================================================================
  // TRIP METADATA STREAMS
  // ============================================================================

  /// Stream trip metas for a user
  Stream<List<TripMeta>> streamTripMetasForUser(String userId) {
    return _firestore
        .collection(_collection)
        .where('member_ids', arrayContains: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => TripMeta.fromJson(d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }
}
