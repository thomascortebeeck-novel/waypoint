import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/trip_model.dart';
import 'package:waypoint/models/trip_meta_model.dart';
import 'package:waypoint/models/trip_selection_model.dart';
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
  static const String _selectionsCollection = 'selections';
  static const String _memberPackingCollection = 'member_packing';
  final UserService _userService = UserService();

  // ============================================================================
  // TRIP METADATA OPERATIONS
  // ============================================================================

  Future<String> createTrip({
    required String planId,
    required String ownerId,
    List<String> memberIds = const [],
    String? title,
    String? inviteCode,
  }) async {
    try {
      // Get plan to check if owner is the creator
      final planDoc = await _firestore.collection('plans').doc(planId).get();
      final isCreator = planDoc.exists && planDoc.data()?['creator_id'] == ownerId;
      
      // Validate owner owns the plan OR is the plan creator
      final owner = await _userService.getUserById(ownerId);
      if (owner == null) {
        throw Exception('Owner not found');
      }
      
      if (!isCreator && !owner.purchasedPlanIds.contains(planId)) {
        throw Exception('Owner must own the plan or be the plan creator to create a trip');
      }

      // Ensure all members own the plan (or skip validation for creator)
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
        inviteCode: inviteCode ?? Trip.generateInviteCode(),
        inviteEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      await doc.set(trip.toJson());
      debugPrint('[TripService] Created trip ${doc.id} for plan $planId, owner $ownerId (isCreator: $isCreator)');
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
          final list = <Trip>[];
          for (final d in s.docs) {
            try {
              list.add(Trip.fromJson(d.data()));
            } catch (e) {
              debugPrint('[TripService] Error parsing trip ${d.id}: $e');
            }
          }
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((e) {
          debugPrint('[TripService] Stream error: $e');
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

  /// Update trip custom cover image
  Future<void> updateTripCustomImage({
    required String tripId,
    required Map<String, String> imageUrls,
    required bool usePlanImage,
  }) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'customImages': imageUrls,
        'usePlanImage': usePlanImage,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating trip custom image: $e');
      rethrow;
    }
  }

  // ============================================================================
  // INVITE MANAGEMENT OPERATIONS
  // ============================================================================

  /// Regenerate invite code for a trip (invalidates old code)
  Future<String> regenerateInviteCode(String tripId) async {
    try {
      final newCode = Trip.generateInviteCode();
      await _firestore.collection(_collection).doc(tripId).update({
        'invite_code': newCode,
        'updated_at': Timestamp.now(),
      });
      return newCode;
    } catch (e) {
      debugPrint('Error regenerating invite code: $e');
      rethrow;
    }
  }

  /// Enable or disable invite link
  Future<void> setInviteEnabled(String tripId, bool enabled) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'invite_enabled': enabled,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error setting invite enabled: $e');
      rethrow;
    }
  }

  /// Get trip by invite code
  Future<Trip?> getTripByInviteCode(String inviteCode) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('invite_code', isEqualTo: inviteCode)
          .limit(1)
          .get();
      
      if (snap.docs.isEmpty) return null;
      return Trip.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('Error getting trip by invite code: $e');
      return null;
    }
  }

  // ============================================================================
  // MEMBER MANAGEMENT OPERATIONS
  // ============================================================================

  /// User leaves trip (cannot be owner)
  Future<void> leaveTrip({required String tripId, required String userId}) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) throw Exception('Trip not found');
      if (trip.ownerId == userId) {
        throw Exception('Owner cannot leave the trip. Transfer ownership or delete the trip.');
      }
      await removeMember(tripId: tripId, userId: userId);
    } catch (e) {
      debugPrint('Error leaving trip: $e');
      rethrow;
    }
  }

  /// Owner removes a member (cannot remove self)
  Future<void> removeMemberByOwner({
    required String tripId,
    required String memberUserId,
    required String requesterId,
  }) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) throw Exception('Trip not found');
      if (trip.ownerId != requesterId) {
        throw Exception('Only the trip owner can remove members');
      }
      if (memberUserId == requesterId) {
        throw Exception('Owner cannot remove themselves');
      }
      await removeMember(tripId: tripId, userId: memberUserId);
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  /// Check if user can join a trip
  Future<bool> canUserJoinTrip(String tripId, String userId, String planId) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) return false;
      
      // Already a member
      if (trip.memberIds.contains(userId)) return false;
      
      // Trip not active
      if (!trip.isActive || trip.status == 'cancelled') return false;
      
      // Invites disabled
      if (!trip.inviteEnabled) return false;
      
      // Check plan ownership
      final user = await _userService.getUserById(userId);
      if (user == null || !user.purchasedPlanIds.contains(planId)) return false;
      
      return true;
    } catch (e) {
      debugPrint('Error checking if user can join: $e');
      return false;
    }
  }

  /// Validate trip access for a user
  Future<bool> validateTripAccess(String tripId, String userId) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) return false;
      return trip.memberIds.contains(userId);
    } catch (e) {
      debugPrint('Error validating trip access: $e');
      return false;
    }
  }

  // ============================================================================
  // TRIP CUSTOMIZATION
  // ============================================================================

  /// Update trip cover image
  Future<void> updateTripImage({
    required String tripId,
    required Map<String, dynamic> customImages,
  }) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'customImages': customImages,
        'usePlanImage': false,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating trip image: $e');
      rethrow;
    }
  }

  /// Update trip details (owner only - validation should be done in UI)
  Future<void> updateTripDetails({
    required String tripId,
    String? title,
    Map<String, dynamic>? customImages,
    bool? usePlanImage,
    DateTime? startDate,
    DateTime? endDate,
    String? versionId,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': Timestamp.now(),
      };
      if (title != null) data['title'] = title;
      if (customImages != null) data['customImages'] = customImages;
      if (usePlanImage != null) data['usePlanImage'] = usePlanImage;
      if (startDate != null) data['start_date'] = Timestamp.fromDate(startDate);
      if (endDate != null) data['end_date'] = Timestamp.fromDate(endDate);
      if (versionId != null) data['version_id'] = versionId;
      
      await _firestore.collection(_collection).doc(tripId).update(data);
    } catch (e) {
      debugPrint('Error updating trip details: $e');
      rethrow;
    }
  }

  /// Update trip status
  Future<void> updateTripStatus({required String tripId, required String status}) async {
    try {
      await _firestore.collection(_collection).doc(tripId).update({
        'status': status,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      rethrow;
    }
  }

  /// Stream a single trip
  Stream<Trip?> streamTrip(String tripId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists ? Trip.fromJson(doc.data()!) : null);
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
      
      // Delete day selections
      final selectionsSnap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .get();
      for (final doc in selectionsSnap.docs) {
        await doc.reference.delete();
      }
      
      // Delete member packing
      final memberPackingSnap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_memberPackingCollection)
          .get();
      for (final doc in memberPackingSnap.docs) {
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

  // ============================================================================
  // CUSTOMIZATION STATUS OPERATIONS
  // ============================================================================

  /// Update trip customization status
  Future<void> updateCustomizationStatus({
    required String tripId,
    required TripCustomizationStatus status,
  }) async {
    try {
      final data = <String, dynamic>{
        'customization_status': status.name,
        'updated_at': Timestamp.now(),
      };
      if (status == TripCustomizationStatus.ready) {
        data['customization_completed_at'] = Timestamp.now();
      }
      await _firestore.collection(_collection).doc(tripId).update(data);
    } catch (e) {
      debugPrint('Error updating customization status: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DAY SELECTIONS OPERATIONS (Creator's waypoint choices)
  // ============================================================================

  /// Get all day selections for a trip
  Future<List<TripDaySelection>> getDaySelections(String tripId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .orderBy('day_num')
          .get();
      return snap.docs.map((d) => TripDaySelection.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting day selections: $e');
      return [];
    }
  }

  /// Get single day selection
  Future<TripDaySelection?> getDaySelection(String tripId, int dayNum) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .doc('day_$dayNum')
          .get();
      if (!doc.exists) return null;
      return TripDaySelection.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting day selection: $e');
      return null;
    }
  }

  /// Initialize empty day selections for a trip
  Future<void> initializeDaySelections({
    required String tripId,
    required int totalDays,
  }) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (var i = 1; i <= totalDays; i++) {
        final selection = TripDaySelection(
          id: 'day_$i',
          tripId: tripId,
          dayNum: i,
          createdAt: now,
          updatedAt: now,
        );
        
        final ref = _firestore
            .collection(_collection)
            .doc(tripId)
            .collection(_selectionsCollection)
            .doc('day_$i');
        batch.set(ref, selection.toJson());
      }
      
      // Also update trip status to customizing
      batch.update(_firestore.collection(_collection).doc(tripId), {
        'customization_status': TripCustomizationStatus.customizing.name,
        'updated_at': Timestamp.now(),
      });
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error initializing day selections: $e');
      rethrow;
    }
  }

  /// Update day selection (accommodation, restaurants, activities)
  Future<void> updateDaySelection(TripDaySelection selection) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(selection.tripId)
          .collection(_selectionsCollection)
          .doc(selection.id)
          .set(selection.copyWith(updatedAt: DateTime.now()).toJson());
    } catch (e) {
      debugPrint('Error updating day selection: $e');
      rethrow;
    }
  }

  /// Update accommodation for a day
  Future<void> updateDayAccommodation({
    required String tripId,
    required int dayNum,
    required SelectedWaypoint? accommodation,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': Timestamp.now(),
      };
      if (accommodation != null) {
        data['selected_accommodation'] = accommodation.toJson();
      } else {
        data['selected_accommodation'] = FieldValue.delete();
      }
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .doc('day_$dayNum')
          .update(data);
    } catch (e) {
      debugPrint('Error updating day accommodation: $e');
      rethrow;
    }
  }

  /// Update restaurants for a day
  Future<void> updateDayRestaurants({
    required String tripId,
    required int dayNum,
    required Map<String, SelectedWaypoint> restaurants,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .doc('day_$dayNum')
          .update({
            'selected_restaurants': restaurants.map((k, v) => MapEntry(k, v.toJson())),
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error updating day restaurants: $e');
      rethrow;
    }
  }

  /// Update activities for a day
  Future<void> updateDayActivities({
    required String tripId,
    required int dayNum,
    required List<SelectedWaypoint> activities,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_selectionsCollection)
          .doc('day_$dayNum')
          .update({
            'selected_activities': activities.map((a) => a.toJson()).toList(),
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error updating day activities: $e');
      rethrow;
    }
  }

  /// Update booking status for a waypoint
  Future<void> updateWaypointBookingStatus({
    required String tripId,
    required int dayNum,
    required String waypointType, // 'accommodation', 'restaurant_breakfast', 'activity_0', etc.
    required WaypointBookingStatus status,
    String? confirmation,
  }) async {
    try {
      final selection = await getDaySelection(tripId, dayNum);
      if (selection == null) return;

      TripDaySelection updated = selection;

      if (waypointType == 'accommodation' && selection.selectedAccommodation != null) {
        updated = selection.copyWith(
          selectedAccommodation: selection.selectedAccommodation!.copyWith(
            bookingStatus: status,
            bookingConfirmation: confirmation,
          ),
        );
      } else if (waypointType.startsWith('restaurant_')) {
        final mealType = waypointType.replaceFirst('restaurant_', '');
        if (selection.selectedRestaurants.containsKey(mealType)) {
          final updatedRestaurants = Map<String, SelectedWaypoint>.from(selection.selectedRestaurants);
          updatedRestaurants[mealType] = selection.selectedRestaurants[mealType]!.copyWith(
            bookingStatus: status,
            bookingConfirmation: confirmation,
          );
          updated = selection.copyWith(selectedRestaurants: updatedRestaurants);
        }
      } else if (waypointType.startsWith('activity_')) {
        final index = int.tryParse(waypointType.replaceFirst('activity_', ''));
        if (index != null && index < selection.selectedActivities.length) {
          final updatedActivities = List<SelectedWaypoint>.from(selection.selectedActivities);
          updatedActivities[index] = selection.selectedActivities[index].copyWith(
            bookingStatus: status,
            bookingConfirmation: confirmation,
          );
          updated = selection.copyWith(selectedActivities: updatedActivities);
        }
      }

      await updateDaySelection(updated);
    } catch (e) {
      debugPrint('Error updating waypoint booking status: $e');
      rethrow;
    }
  }

  /// Stream day selections
  Stream<List<TripDaySelection>> streamDaySelections(String tripId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_selectionsCollection)
        .orderBy('day_num')
        .snapshots()
        .map((s) => s.docs.map((d) => TripDaySelection.fromJson(d.data())).toList());
  }

  /// Stream single day selection
  Stream<TripDaySelection?> streamDaySelection(String tripId, int dayNum) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_selectionsCollection)
        .doc('day_$dayNum')
        .snapshots()
        .map((doc) => doc.exists ? TripDaySelection.fromJson(doc.data()!) : null);
  }

  // ============================================================================
  // MEMBER PACKING OPERATIONS (Individual member checklists)
  // ============================================================================

  /// Get member packing for a user
  Future<MemberPacking?> getMemberPacking(String tripId, String memberId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_memberPackingCollection)
          .doc(memberId)
          .get();
      if (!doc.exists) return null;
      return MemberPacking.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting member packing: $e');
      return null;
    }
  }

  /// Get all member packings for a trip
  Future<List<MemberPacking>> getAllMemberPackings(String tripId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_memberPackingCollection)
          .get();
      return snap.docs.map((d) => MemberPacking.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Error getting all member packings: $e');
      return [];
    }
  }

  /// Initialize member packing for a new member
  Future<void> initializeMemberPacking({
    required String tripId,
    required String memberId,
    required List<String> itemIds,
  }) async {
    try {
      final now = DateTime.now();
      final packing = MemberPacking(
        id: memberId,
        tripId: tripId,
        memberId: memberId,
        items: {for (final id in itemIds) id: false},
        createdAt: now,
        updatedAt: now,
      );
      
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_memberPackingCollection)
          .doc(memberId)
          .set(packing.toJson());
    } catch (e) {
      debugPrint('Error initializing member packing: $e');
      rethrow;
    }
  }

  /// Toggle packing item for a member
  Future<void> toggleMemberPackingItem({
    required String tripId,
    required String memberId,
    required String itemId,
    required bool checked,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tripId)
          .collection(_memberPackingCollection)
          .doc(memberId)
          .update({
            'items.$itemId': checked,
            'updated_at': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error toggling member packing item: $e');
      rethrow;
    }
  }

  /// Stream member packing
  Stream<MemberPacking?> streamMemberPacking(String tripId, String memberId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_memberPackingCollection)
        .doc(memberId)
        .snapshots()
        .map((doc) => doc.exists ? MemberPacking.fromJson(doc.data()!) : null);
  }

  /// Stream all member packings for a trip
  Stream<List<MemberPacking>> streamAllMemberPackings(String tripId) {
    return _firestore
        .collection(_collection)
        .doc(tripId)
        .collection(_memberPackingCollection)
        .snapshots()
        .map((s) => s.docs.map((d) => MemberPacking.fromJson(d.data())).toList());
  }
}
