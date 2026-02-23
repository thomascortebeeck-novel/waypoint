import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/plan_meta_model.dart';
import 'package:waypoint/models/plan_version_model.dart';
import 'package:waypoint/models/day_itinerary_model.dart';
import 'package:waypoint/models/route_waypoint.dart';

/// Service for managing plans with hybrid subcollection architecture
/// 
/// Structure:
/// - plans/{planId} - PlanMeta (lightweight metadata for listings)
/// - plans/{planId}/versions/{versionId} - PlanVersionDoc (full version data)
/// - plans/{planId}/versions/{versionId}/days/{dayId} - DayItineraryDoc (day with routes)
/// - plans/{planId}/versions/{versionId}/days/{dayId}/waypoints/{wpId} - WaypointDoc
class PlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'plans';
  static const String _versionsCollection = 'versions';
  static const String _daysCollection = 'days';
  static const String _waypointsCollection = 'waypoints';

  // ============================================================================
  // PLAN METADATA OPERATIONS (Lightweight - for marketplace listings)
  // ============================================================================

  /// Get all published plan metadata
  /// [userId] - Optional user ID for privacy filtering
  /// [userFollowingList] - Optional list of creator IDs the user follows (for followers-only plans)
  Future<List<PlanMeta>> getAllPlanMetas({
    String? userId,
    List<String>? userFollowingList,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      final allPlans = snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
      
      // Apply privacy filtering if user context provided
      if (userId != null || userFollowingList != null) {
        return allPlans.where((plan) => _canUserSeePlan(
          plan,
          userId,
          userFollowingList,
        )).toList();
      }
      
      // If no user context, only show public plans
      return allPlans.where((plan) => plan.privacyMode == PlanPrivacyMode.public).toList();
    } catch (e) {
      debugPrint('Error getting all plan metas: $e');
      return [];
    }
  }

  /// Get featured plan metadata
  /// [userId] - Optional user ID for privacy filtering
  /// [userFollowingList] - Optional list of creator IDs the user follows (for followers-only plans)
  Future<List<PlanMeta>> getFeaturedPlanMetas({
    String? userId,
    List<String>? userFollowingList,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_featured', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      final allPlans = snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
      
      // Apply privacy filtering if user context provided
      if (userId != null || userFollowingList != null) {
        return allPlans.where((plan) => _canUserSeePlan(
          plan,
          userId,
          userFollowingList,
        )).toList();
      }
      
      // If no user context, only show public plans
      return allPlans.where((plan) => plan.privacyMode == PlanPrivacyMode.public).toList();
    } catch (e) {
      debugPrint('Error getting featured plan metas: $e');
      return [];
    }
  }

  /// Get discover plan metadata
  /// [userId] - Optional user ID for privacy filtering
  /// [userFollowingList] - Optional list of creator IDs the user follows (for followers-only plans)
  Future<List<PlanMeta>> getDiscoverPlanMetas({
    String? userId,
    List<String>? userFollowingList,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_discover', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      final allPlans = snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
      
      // Apply privacy filtering if user context provided
      if (userId != null || userFollowingList != null) {
        return allPlans.where((plan) => _canUserSeePlan(
          plan,
          userId,
          userFollowingList,
        )).toList();
      }
      
      // If no user context, only show public plans
      return allPlans.where((plan) => plan.privacyMode == PlanPrivacyMode.public).toList();
    } catch (e) {
      debugPrint('Error getting discover plan metas: $e');
      return [];
    }
  }

  /// Get plan metadata by ID
  Future<PlanMeta?> getPlanMetaById(String planId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(planId).get();
      if (!doc.exists) return null;
      return PlanMeta.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting plan meta: $e');
      return null;
    }
  }

  /// Get plan metadata by creator
  Future<List<PlanMeta>> getPlanMetasByCreator(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('creator_id', isEqualTo: creatorId)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting plan metas by creator: $e');
      return [];
    }
  }

  /// Get plan metas by IDs
  Future<List<PlanMeta>> getPlanMetasByIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < planIds.length; i += 30) {
        chunks.add(planIds.sublist(i, i + 30 > planIds.length ? planIds.length : i + 30));
      }
      final metas = <PlanMeta>[];
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        metas.addAll(snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())));
      }
      return metas;
    } catch (e) {
      debugPrint('Error getting plan metas by IDs: $e');
      return [];
    }
  }

  /// Stream plan metas
  Stream<List<PlanMeta>> streamAllPlanMetas() {
    return _firestore
        .collection(_collection)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => PlanMeta.fromJson(d.data())).toList());
  }

  /// Stream featured plan metas
  Stream<List<PlanMeta>> streamFeaturedPlanMetas() {
    return _firestore
        .collection(_collection)
        .where('is_featured', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((s) {
          final metas = s.docs.map((d) => PlanMeta.fromJson(d.data())).toList();
          metas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return metas;
        });
  }

  /// Stream discover plan metas
  Stream<List<PlanMeta>> streamDiscoverPlanMetas() {
    return _firestore
        .collection(_collection)
        .where('is_discover', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((s) {
          final metas = s.docs.map((d) => PlanMeta.fromJson(d.data())).toList();
          metas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return metas;
        });
  }

  /// Stream plans by creator
  Stream<List<PlanMeta>> streamPlanMetasByCreator(String creatorId) {
    return _firestore
        .collection(_collection)
        .where('creator_id', isEqualTo: creatorId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PlanMeta.fromJson(d.data())).toList());
  }

  // ============================================================================
  // VERSION OPERATIONS (Subcollection)
  // ============================================================================

  /// Get all versions for a plan
  Future<List<PlanVersionDoc>> getVersions(String planId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .orderBy('created_at')
          .get();
      return snapshot.docs.map((doc) => PlanVersionDoc.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting versions: $e');
      return [];
    }
  }

  /// Get a specific version
  Future<PlanVersionDoc?> getVersion(String planId, String versionId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .get();
      if (!doc.exists) return null;
      return PlanVersionDoc.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting version: $e');
      return null;
    }
  }

  /// Create or update a version
  Future<void> saveVersion(PlanVersionDoc version) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(version.planId)
          .collection(_versionsCollection)
          .doc(version.id)
          .set(version.toJson());
    } catch (e) {
      debugPrint('Error saving version: $e');
      rethrow;
    }
  }

  /// Delete a version and its subcollections
  Future<void> deleteVersion(String planId, String versionId) async {
    try {
      // First delete all days and their waypoints
      final days = await getDays(planId, versionId);
      for (final day in days) {
        await deleteDay(planId, versionId, day.id);
      }
      // Then delete the version
      await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting version: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DAY OPERATIONS (Subcollection)
  // ============================================================================

  /// Get all days for a version
  Future<List<DayItineraryDoc>> getDays(String planId, String versionId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .collection(_daysCollection)
          .orderBy('day_num')
          .get();
      return snapshot.docs.map((doc) => DayItineraryDoc.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting days: $e');
      return [];
    }
  }

  /// Get a specific day
  Future<DayItineraryDoc?> getDay(String planId, String versionId, String dayId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .collection(_daysCollection)
          .doc(dayId)
          .get();
      if (!doc.exists) return null;
      return DayItineraryDoc.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting day: $e');
      return null;
    }
  }

  /// Create or update a day
  Future<void> saveDay(DayItineraryDoc day) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(day.planId)
          .collection(_versionsCollection)
          .doc(day.versionId)
          .collection(_daysCollection)
          .doc(day.id)
          .set(day.toJson());
    } catch (e) {
      debugPrint('Error saving day: $e');
      rethrow;
    }
  }

  /// Delete a day and its waypoints
  Future<void> deleteDay(String planId, String versionId, String dayId) async {
    try {
      // First delete all waypoints
      final waypoints = await getWaypoints(planId, versionId, dayId);
      for (final wp in waypoints) {
        await deleteWaypoint(planId, versionId, dayId, wp.id);
      }
      // Then delete the day
      await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .collection(_daysCollection)
          .doc(dayId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting day: $e');
      rethrow;
    }
  }

  // ============================================================================
  // WAYPOINT OPERATIONS (Subcollection)
  // ============================================================================

  /// Get all waypoints for a day
  Future<List<WaypointDoc>> getWaypoints(String planId, String versionId, String dayId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .collection(_daysCollection)
          .doc(dayId)
          .collection(_waypointsCollection)
          .orderBy('waypoint.order')
          .get();
      return snapshot.docs.map((doc) => WaypointDoc.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting waypoints: $e');
      return [];
    }
  }

  /// Save a waypoint
  Future<void> saveWaypoint(WaypointDoc waypoint, String dayId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(waypoint.planId)
          .collection(_versionsCollection)
          .doc(waypoint.versionId)
          .collection(_daysCollection)
          .doc(dayId)
          .collection(_waypointsCollection)
          .doc(waypoint.id)
          .set(waypoint.toJson());
    } catch (e) {
      debugPrint('Error saving waypoint: $e');
      rethrow;
    }
  }

  /// Delete a waypoint
  Future<void> deleteWaypoint(String planId, String versionId, String dayId, String waypointId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .collection(_daysCollection)
          .doc(dayId)
          .collection(_waypointsCollection)
          .doc(waypointId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting waypoint: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LEGACY COMPATIBILITY (Full Plan objects)
  // ============================================================================

  /// Get all published plans (legacy format)
  Future<List<Plan>> getAllPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all plans: $e');
      return [];
    }
  }

  /// Get featured plans (legacy format)
  Future<List<Plan>> getFeaturedPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_featured', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      return snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting featured plans: $e');
      return [];
    }
  }

  /// Get discover plans (legacy format)
  Future<List<Plan>> getDiscoverPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_discover', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting discover plans: $e');
      return [];
    }
  }

  /// Get plan by ID (legacy format)
  /// This now automatically detects and loads from subcollections if available
  Future<Plan?> getPlanById(String planId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(planId).get();
      if (!doc.exists) return null;
      
      // Check if plan uses subcollection structure
      final versionsSnap = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .limit(1)
          .get();
      
      if (versionsSnap.docs.isNotEmpty) {
        // Plan uses subcollections - load full plan with versions
        return await loadFullPlan(planId);
      }
      
      // Legacy format - versions embedded in document
      return Plan.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting plan: $e');
      return null;
    }
  }

  /// Get plans by creator (legacy format)
  Future<List<Plan>> getPlansByCreator(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('creator_id', isEqualTo: creatorId)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting plans by creator: $e');
      return [];
    }
  }

  /// Get plans by IDs (legacy format)
  /// This now automatically detects and loads from subcollections if available
  Future<List<Plan>> getPlansByIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    try {
      final plans = <Plan>[];
      
      // Load each plan individually to properly handle subcollections
      for (final planId in planIds) {
        try {
          final plan = await getPlanById(planId);
          if (plan != null) {
            plans.add(plan);
          }
        } catch (e) {
          debugPrint('[PlanService] Error loading plan $planId: $e');
        }
      }
      
      return plans;
    } catch (e) {
      debugPrint('Error getting plans by IDs: $e');
      return [];
    }
  }

  /// Create a new plan with subcollection architecture from the start
  Future<String> createPlan(Plan plan) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final planWithId = plan.copyWith(id: docRef.id);
      
      // Use a batch for atomic writes
      final batch = _firestore.batch();
      
      // Write main plan document with ONLY metadata (no embedded versions)
      final planMeta = PlanMeta.fromPlan(planWithId);
      batch.set(docRef, planMeta.toJson());
      
      // Write versions as subcollections
      for (final version in planWithId.versions) {
        final versionDoc = PlanVersionDoc.fromPlanVersion(version, docRef.id);
        final versionRef = docRef.collection(_versionsCollection).doc(version.id);
        batch.set(versionRef, versionDoc.toJson());
        
        // Write days as subcollections
        for (final day in version.days) {
          final dayDoc = DayItineraryDoc.fromDayItinerary(day, docRef.id, version.id);
          final dayRef = versionRef.collection(_daysCollection).doc(dayDoc.id);
          batch.set(dayRef, dayDoc.toJson());
        }
      }
      
      await batch.commit();
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating plan: $e');
      rethrow;
    }
  }

  /// Update a plan metadata (does not update subcollections)
  /// NOTE: Use updatePlanWithVersions for full CRUD operations including versions/days
  Future<void> updatePlan(Plan plan) async {
    try {
      // Only update metadata, not subcollections
      final planMeta = PlanMeta.fromPlan(plan.copyWith(updatedAt: DateTime.now()));
      await _firestore.collection(_collection).doc(plan.id).update(planMeta.toJson());
    } catch (e) {
      debugPrint('Error updating plan: $e');
      rethrow;
    }
  }

  /// Update a plan including all versions and days (full CRUD)
  /// This properly saves versions to subcollections and days within each version
  Future<void> updatePlanWithVersions(Plan plan) async {
    try {
      final planId = plan.id;
      final updatedPlan = plan.copyWith(updatedAt: DateTime.now());
      
      // Use a batch for atomic writes
      final batch = _firestore.batch();
      
      // 1. Update main plan metadata document
      final planMeta = PlanMeta.fromPlan(updatedPlan);
      final planRef = _firestore.collection(_collection).doc(planId);
      batch.set(planRef, planMeta.toJson(), SetOptions(merge: true));
      
      // 2. Get existing versions to handle deletions
      final existingVersionsSnap = await planRef.collection(_versionsCollection).get();
      final existingVersionIds = existingVersionsSnap.docs.map((d) => d.id).toSet();
      final newVersionIds = updatedPlan.versions.map((v) => v.id).toSet();
      
      // Delete versions that no longer exist
      for (final oldVersionId in existingVersionIds.difference(newVersionIds)) {
        // Delete all days in this version first
        final daysSnap = await planRef
            .collection(_versionsCollection)
            .doc(oldVersionId)
            .collection(_daysCollection)
            .get();
        for (final dayDoc in daysSnap.docs) {
          batch.delete(dayDoc.reference);
        }
        // Delete the version
        batch.delete(planRef.collection(_versionsCollection).doc(oldVersionId));
      }
      
      await batch.commit();
      
      // 3. Update/create versions and days (in a new batch to avoid size limits)
      for (final version in updatedPlan.versions) {
        final versionBatch = _firestore.batch();
        
        // Convert and save version document
        final versionDoc = PlanVersionDoc.fromPlanVersion(version, planId);
        final versionRef = planRef.collection(_versionsCollection).doc(version.id);
        versionBatch.set(versionRef, versionDoc.toJson());
        
        // Get existing days to handle deletions
        final existingDaysSnap = await versionRef.collection(_daysCollection).get();
        final existingDayIds = existingDaysSnap.docs.map((d) => d.id).toSet();
        final newDayIds = version.days.map((d) => 'day_${d.dayNum}').toSet();
        
        // Delete days that no longer exist
        for (final oldDayId in existingDayIds.difference(newDayIds)) {
          versionBatch.delete(versionRef.collection(_daysCollection).doc(oldDayId));
        }
        
        // Update/create days
        for (final day in version.days) {
          final dayDoc = DayItineraryDoc.fromDayItinerary(day, planId, version.id);
          final dayRef = versionRef.collection(_daysCollection).doc(dayDoc.id);
          versionBatch.set(dayRef, dayDoc.toJson());
        }
        
        await versionBatch.commit();
      }
      
      debugPrint('Successfully updated plan with versions: $planId');
    } catch (e) {
      debugPrint('Error updating plan with versions: $e');
      rethrow;
    }
  }

  /// Update FAQ items for a plan (plan-level, shared across versions)
  Future<void> updateFaqItems(String planId, List<FAQItem> faqItems) async {
    try {
      await _firestore.collection(_collection).doc(planId).update({
        'faq_items': faqItems.map((f) => f.toJson()).toList(),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating FAQ items: $e');
      rethrow;
    }
  }

  /// Update packing categories for a version
  Future<void> updatePackingCategories(
    String planId,
    String versionId,
    List<PackingCategory> categories,
  ) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .update({
        'packing_categories': categories.map((c) => c.toJson()).toList(),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating packing categories: $e');
      rethrow;
    }
  }

  /// Update transportation options for a version
  Future<void> updateTransportationOptions(
    String planId,
    String versionId,
    List<TransportationOption> options,
  ) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .doc(versionId)
          .update({
        'transportation_options': options.map((t) => t.toJson()).toList(),
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating transportation options: $e');
      rethrow;
    }
  }

  /// Delete a plan and all subcollections
  Future<void> deletePlan(String planId) async {
    try {
      // Delete all versions (which deletes days and waypoints)
      final versions = await getVersions(planId);
      for (final version in versions) {
        await deleteVersion(planId, version.id);
      }
      // Delete main document
      await _firestore.collection(_collection).doc(planId).delete();
    } catch (e) {
      debugPrint('Error deleting plan: $e');
      rethrow;
    }
  }

  /// Stream all published plans (legacy format)
  Stream<List<Plan>> streamAllPlans() {
    return _firestore
        .collection(_collection)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Plan.fromJson(d.data())).toList());
  }

  /// Stream featured plans (legacy format)
  Stream<List<Plan>> streamFeaturedPlans() {
    return _firestore
        .collection(_collection)
        .where('is_featured', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((s) {
          final plans = s.docs.map((d) => Plan.fromJson(d.data())).toList();
          plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return plans;
        });
  }

  /// Stream discover plans (legacy format)
  Stream<List<Plan>> streamDiscoverPlans() {
    return _firestore
        .collection(_collection)
        .where('is_discover', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((s) {
          final plans = s.docs.map((d) => Plan.fromJson(d.data())).toList();
          plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return plans;
        });
  }

  /// Stream plans by creator (legacy format)
  Stream<List<Plan>> streamPlansByCreator(String creatorId) {
    return _firestore
        .collection(_collection)
        .where('creator_id', isEqualTo: creatorId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Plan.fromJson(d.data())).toList());
  }

  /// Search published plans by location and name
  /// Searches for plans where location or name contains the query (case-insensitive)
  /// [userId] - Optional user ID for privacy filtering
  /// [userFollowingList] - Optional list of creator IDs the user follows (for followers-only plans)
  Future<List<Plan>> searchPlans(
    String query, {
    String? userId,
    List<String>? userFollowingList,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }
    
    try {
      final lowerQuery = query.toLowerCase().trim();
      
      // Get all published plans (we'll filter in memory for text search)
      // Firestore doesn't support case-insensitive text search natively
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .limit(200) // Get more results to filter from
          .get();
      
      final allPlans = snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
      
      // Apply privacy filtering first
      final privacyFilteredPlans = (userId != null || userFollowingList != null)
          ? allPlans.where((plan) => _canUserSeeFullPlan(
              plan,
              userId,
              userFollowingList,
            )).toList()
          : allPlans.where((plan) => plan.privacyMode == PlanPrivacyMode.public).toList();
      
      // Filter plans where name or location contains the query
      final filteredPlans = privacyFilteredPlans.where((plan) {
        final nameMatch = plan.name.toLowerCase().contains(lowerQuery);
        final locationMatch = plan.location.toLowerCase().contains(lowerQuery);
        return nameMatch || locationMatch;
      }).toList();
      
      // Sort by relevance (exact matches first, then by creation date)
      filteredPlans.sort((a, b) {
        final aNameExact = a.name.toLowerCase() == lowerQuery;
        final bNameExact = b.name.toLowerCase() == lowerQuery;
        final aLocationExact = a.location.toLowerCase() == lowerQuery;
        final bLocationExact = b.location.toLowerCase() == lowerQuery;
        
        if (aNameExact && !bNameExact) return -1;
        if (!aNameExact && bNameExact) return 1;
        if (aLocationExact && !bLocationExact) return -1;
        if (!aLocationExact && bLocationExact) return 1;
        
        // Otherwise sort by creation date (newest first)
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return filteredPlans.take(50).toList(); // Limit to 50 results
    } catch (e) {
      debugPrint('Error searching plans: $e');
      return [];
    }
  }

  /// Stream search results for published plans
  Stream<List<Plan>> streamSearchPlans(String query) {
    if (query.trim().isEmpty) {
      return Stream.value([]);
    }
    
    // For streaming, we'll use a periodic refresh approach
    // In a production app, you might want to use Algolia or similar for better search
    return Stream.periodic(const Duration(milliseconds: 500), (_) => query)
        .asyncMap((q) => searchPlans(q))
        .distinct();
  }

  // ============================================================================
  // FULL PLAN LOADING (For itinerary viewing - loads from subcollections)
  // ============================================================================

  /// Load full plan with all version details from subcollections
  Future<Plan?> loadFullPlan(String planId) async {
    try {
      // Get plan metadata
      final planDoc = await _firestore.collection(_collection).doc(planId).get();
      if (!planDoc.exists) return null;
      
      final planData = planDoc.data()!;
      
      // Check if using new subcollection structure
      final versionsSnap = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .get();
      
      if (versionsSnap.docs.isEmpty) {
        // Legacy format - versions embedded in document
        return Plan.fromJson(planData);
      }
      
      // New format - load from subcollections
      // Load plan-level data (FAQ items, price, categorization)
      final planFaqItems = (planData['faq_items'] as List<dynamic>?)
          ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
          .toList() ?? <FAQItem>[];
      final planPrice = (planData['base_price'] as num?)?.toDouble() ?? 0.0;
      final ActivityCategory? activityCategory = planData['activity_category'] != null
          ? ActivityCategory.values.firstWhere(
              (e) => e.name == planData['activity_category'],
              orElse: () => ActivityCategory.hiking,
            )
          : null;
      final AccommodationType? accommodationType = planData['accommodation_type'] != null
          ? AccommodationType.values.firstWhere(
              (e) => e.name == planData['accommodation_type'],
              orElse: () => AccommodationType.comfort,
            )
          : null;
      
      final versions = <PlanVersion>[];
      for (final versionDoc in versionsSnap.docs) {
        final versionData = PlanVersionDoc.fromJson(versionDoc.data());
        
        // Load days for this version
        final daysSnap = await _firestore
            .collection(_collection)
            .doc(planId)
            .collection(_versionsCollection)
            .doc(versionData.id)
            .collection(_daysCollection)
            .orderBy('day_num')
            .get();
        
        final days = daysSnap.docs
            .map((d) => DayItineraryDoc.fromJson(d.data()).toDayItinerary())
            .toList();
        
        // Convert to PlanVersion and inject plan-level data (FAQ items and price)
        final planVersion = versionData.toPlanVersion(days);
        versions.add(PlanVersion(
          id: planVersion.id,
          name: planVersion.name,
          durationDays: planVersion.durationDays,
          difficulty: Difficulty.none, // Deprecated - use default
          comfortType: ComfortType.none, // Deprecated - use default
          price: planPrice, // Price from plan level
          days: planVersion.days,
          packingCategories: planVersion.packingCategories,
          transportationOptions: planVersion.transportationOptions,
          faqItems: planFaqItems, // FAQ from plan level
          prepare: versionData.prepare, // Prepare from version
          localTips: versionData.localTips, // LocalTips from version
          aiGeneratedAt: versionData.aiGeneratedAt, // AI timestamp from version
        ));
      }
      
      // Build Plan from metadata + loaded versions. IMPORTANT: include plan-level
      // fields like faq_items and categorization so editors show saved values.
      return Plan(
        id: planData['id'] as String,
        name: planData['name'] as String,
        description: planData['description'] as String,
        heroImageUrl: planData['hero_image_url'] as String,
        location: planData['location'] as String,
        basePrice: (planData['base_price'] as num).toDouble(),
        creatorId: planData['creator_id'] as String,
        creatorName: planData['creator_name'] as String,
        versions: versions,
        isFeatured: planData['is_featured'] as bool? ?? false,
        isDiscover: planData['is_discover'] as bool? ?? false,
        isPublished: planData['is_published'] as bool? ?? true,
        favoriteCount: (planData['favorite_count'] as num?)?.toInt() ?? 0,
        salesCount: (planData['sales_count'] as num?)?.toInt() ?? 0,
        createdAt: (planData['created_at'] as Timestamp).toDate(),
        updatedAt: (planData['updated_at'] as Timestamp).toDate(),
        activityCategory: activityCategory,
        accommodationType: accommodationType,
        faqItems: planFaqItems,
      );
    } catch (e) {
      debugPrint('Error loading full plan: $e');
      return null;
    }
  }

  /// Get lightweight version summaries for a plan (no full version loading)
  /// This is optimized for version selector dropdown display
  Future<List<VersionSummary>> getVersionSummaries(String planId) async {
    try {
      // First try to get from plan metadata (stored version_summaries)
      final planDoc = await _firestore.collection(_collection).doc(planId).get();
      if (!planDoc.exists) return [];
      
      final planData = planDoc.data()!;
      final storedSummaries = planData['version_summaries'] as List<dynamic>?;
      
      if (storedSummaries != null && storedSummaries.isNotEmpty) {
        return storedSummaries
            .map((v) => VersionSummary.fromJson(v as Map<String, dynamic>))
            .toList();
      }
      
      // Fallback: Load from version subcollection (lightweight read)
      final versionsSnap = await _firestore
          .collection(_collection)
          .doc(planId)
          .collection(_versionsCollection)
          .orderBy('created_at')
          .get();
      
      if (versionsSnap.docs.isEmpty) {
        // Legacy format - extract from embedded versions
        final legacyVersions = planData['versions'] as List<dynamic>?;
        if (legacyVersions != null) {
          return legacyVersions.map((v) {
            final vData = v as Map<String, dynamic>;
            return VersionSummary(
              id: vData['id'] as String,
              name: vData['name'] as String,
              durationDays: vData['duration_days'] as int,
              difficulty: Difficulty.values.firstWhere(
                (d) => d.name == vData['difficulty'],
                orElse: () => Difficulty.none,
              ),
            );
          }).toList();
        }
        return [];
      }
      
      // Build summaries from version docs with calculated stats from days
      final summaries = <VersionSummary>[];
      for (final versionDoc in versionsSnap.docs) {
        final data = versionDoc.data();
        final versionId = data['id'] as String;
        
        // Load days for this version to calculate stats
        final daysSnap = await _firestore
            .collection(_collection)
            .doc(planId)
            .collection(_versionsCollection)
            .doc(versionId)
            .collection(_daysCollection)
            .get();
        
        double totalDistance = 0;
        double totalElevation = 0;
        int waypointCount = 0;
        
        for (final dayDoc in daysSnap.docs) {
          final dayData = dayDoc.data();
          final routeData = dayData['route'] as Map<String, dynamic>?;
          if (routeData != null) {
            totalDistance += (routeData['distance'] as num?)?.toDouble() ?? 0;
            totalElevation += (routeData['ascent'] as num?)?.toDouble() ?? 0;
            final poiWaypoints = routeData['poi_waypoints'] as List<dynamic>?;
            waypointCount += poiWaypoints?.length ?? 0;
          }
          // Count legacy waypoints
          waypointCount += (dayData['accommodations'] as List<dynamic>?)?.length ?? 0;
          waypointCount += (dayData['restaurants'] as List<dynamic>?)?.length ?? 0;
          waypointCount += (dayData['activities'] as List<dynamic>?)?.length ?? 0;
        }
        
        summaries.add(VersionSummary(
          id: versionId,
          name: data['name'] as String,
          durationDays: data['duration_days'] as int,
          difficulty: Difficulty.none,
          totalDistanceKm: totalDistance / 1000,
          totalElevationM: totalElevation,
          waypointCount: waypointCount,
        ));
      }
      
      // Store calculated summaries back to plan document for future reads
      _updateVersionSummaries(planId, summaries);
      
      return summaries;
    } catch (e) {
      debugPrint('Error getting version summaries: $e');
      return [];
    }
  }
  
  /// Update version_summaries on the plan document (fire-and-forget)
  Future<void> _updateVersionSummaries(String planId, List<VersionSummary> summaries) async {
    try {
      await _firestore.collection(_collection).doc(planId).update({
        'version_summaries': summaries.map((s) => s.toJson()).toList(),
      });
      debugPrint('Updated version summaries for plan $planId');
    } catch (e) {
      // Non-critical - just log the error
      debugPrint('Failed to update version summaries: $e');
    }
  }

  /// Load plan metadata only (without loading full version data)
  /// Returns PlanMeta with version summaries for dropdown display
  Future<PlanMeta?> loadPlanMeta(String planId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(planId).get();
      if (!doc.exists) return null;
      
      var meta = PlanMeta.fromJson(doc.data()!);
      
      // If no stored version summaries, fetch them
      if (meta.versionSummaries.isEmpty) {
        final summaries = await getVersionSummaries(planId);
        meta = meta.copyWith(versionSummaries: summaries);
      }
      
      return meta;
    } catch (e) {
      debugPrint('Error loading plan meta: $e');
      return null;
    }
  }

  /// Load a single version with all days
  Future<PlanVersion?> loadFullVersion(String planId, String versionId) async {
    try {
      final versionDoc = await getVersion(planId, versionId);
      if (versionDoc == null) return null;
      
      final days = await getDays(planId, versionId);
      final dayItineraries = days.map((d) => d.toDayItinerary()).toList();
      
      // Load plan-level data (FAQ items and price)
      final planDoc = await _firestore.collection(_collection).doc(planId).get();
      final planFaqItems = planDoc.exists
          ? (planDoc.data()!['faq_items'] as List<dynamic>?)
              ?.map((f) => FAQItem.fromJson(f as Map<String, dynamic>))
              .toList() ?? <FAQItem>[]
          : <FAQItem>[];
      final planPrice = planDoc.exists
          ? (planDoc.data()!['base_price'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      
      // Convert to PlanVersion and inject plan-level data (FAQ, price)
      final planVersion = versionDoc.toPlanVersion(dayItineraries);
      return PlanVersion(
        id: planVersion.id,
        name: planVersion.name,
        durationDays: planVersion.durationDays,
        difficulty: Difficulty.none, // Deprecated - use default
        comfortType: ComfortType.none, // Deprecated - use default
        price: planPrice, // Price from plan level
        days: planVersion.days,
        packingCategories: planVersion.packingCategories,
        transportationOptions: planVersion.transportationOptions,
        faqItems: planFaqItems, // FAQ from plan level
      );
    } catch (e) {
      debugPrint('Error loading full version: $e');
      return null;
    }
  }

  // ============================================================================
  // FEED OPERATIONS (Fan-out pattern for following)
  // ============================================================================

  /// Get plans from user's feed (fan-out pattern)
  /// Queries users/{userId}/feed collection
  Future<List<Plan>> getFeedPlans(String userId) async {
    try {
      final feedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('feed')
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();

      if (feedSnapshot.docs.isEmpty) {
        return [];
      }

      // Extract plan IDs from feed documents
      final planIds = feedSnapshot.docs
          .map((doc) => doc.data()['plan_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (planIds.isEmpty) {
        return [];
      }

      // Load full plans
      return await getPlansByIds(planIds);
    } catch (e) {
      debugPrint('[PlanService] Error getting feed plans: $e');
      return [];
    }
  }

  /// Stream plans from user's feed (real-time updates)
  Stream<List<Plan>> streamFeedPlans(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('feed')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return <Plan>[];
      }

      final planIds = snapshot.docs
          .map((doc) => doc.data()['plan_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (planIds.isEmpty) {
        return <Plan>[];
      }

      return await getPlansByIds(planIds);
    });
  }

  // ============================================================================
  // MIGRATION UTILITIES
  // ============================================================================

  /// Migrate a legacy plan to subcollection structure
  Future<void> migratePlanToSubcollections(String planId) async {
    try {
      // Load legacy plan
      final plan = await getPlanById(planId);
      if (plan == null) {
        debugPrint('Plan not found for migration: $planId');
        return;
      }
      
      // Update metadata with version summaries
      final meta = PlanMeta.fromPlan(plan);
      await _firestore.collection(_collection).doc(planId).update(meta.toJson());
      
      // Create subcollection documents
      for (final version in plan.versions) {
        final versionDoc = PlanVersionDoc.fromPlanVersion(version, planId);
        await saveVersion(versionDoc);
        
        for (final day in version.days) {
          final dayDoc = DayItineraryDoc.fromDayItinerary(day, planId, version.id);
          await saveDay(dayDoc);
        }
      }
      
      debugPrint('Successfully migrated plan $planId to subcollections');
    } catch (e) {
      debugPrint('Error migrating plan: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PRIVACY FILTERING HELPERS
  // ============================================================================

  /// Get user's following list from Firestore
  /// Returns list of creator IDs the user follows
  Future<List<String>> getUserFollowingList(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting user following list: $e');
      return [];
    }
  }

  /// Check if user can see a plan based on privacy mode
  /// [plan] - The plan to check
  /// [userId] - Optional user ID (for invited plans)
  /// [userFollowingList] - Optional list of creator IDs user follows (for followers-only plans)
  bool _canUserSeePlan(
    PlanMeta plan,
    String? userId,
    List<String>? userFollowingList,
  ) {
    switch (plan.privacyMode) {
      case PlanPrivacyMode.public:
        // Public plans visible to everyone
        return true;
      
      case PlanPrivacyMode.followers:
        // Followers-only plans: user must follow the creator
        if (userFollowingList == null) return false;
        return userFollowingList.contains(plan.creatorId);
      
      case PlanPrivacyMode.invited:
        // Invited plans: user must be in invited list
        // NOTE: This requires checking user's invitedPlanIds, which should be passed separately
        // For now, only show if user is the creator
        if (userId == null) return false;
        return userId == plan.creatorId;
    }
  }

  /// Check if user can see a Plan (not PlanMeta) based on privacy mode
  /// [plan] - The plan to check
  /// [userId] - Optional user ID (for invited plans)
  /// [userFollowingList] - Optional list of creator IDs user follows (for followers-only plans)
  bool _canUserSeeFullPlan(
    Plan plan,
    String? userId,
    List<String>? userFollowingList,
  ) {
    switch (plan.privacyMode) {
      case PlanPrivacyMode.public:
        // Public plans visible to everyone
        return true;
      
      case PlanPrivacyMode.followers:
        // Followers-only plans: user must follow the creator
        if (userFollowingList == null) return false;
        return userFollowingList.contains(plan.creatorId);
      
      case PlanPrivacyMode.invited:
        // Invited plans: user must be in invited list
        // NOTE: This requires checking user's invitedPlanIds, which should be passed separately
        // For now, only show if user is the creator
        if (userId == null) return false;
        return userId == plan.creatorId;
    }
  }
}
