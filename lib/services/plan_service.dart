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
  Future<List<PlanMeta>> getAllPlanMetas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all plan metas: $e');
      return [];
    }
  }

  /// Get featured plan metadata
  Future<List<PlanMeta>> getFeaturedPlanMetas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_featured', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      return snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting featured plan metas: $e');
      return [];
    }
  }

  /// Get discover plan metadata
  Future<List<PlanMeta>> getDiscoverPlanMetas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_discover', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => PlanMeta.fromJson(doc.data())).toList();
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
  Future<Plan?> getPlanById(String planId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(planId).get();
      if (!doc.exists) return null;
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
  Future<List<Plan>> getPlansByIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < planIds.length; i += 30) {
        chunks.add(planIds.sublist(i, i + 30 > planIds.length ? planIds.length : i + 30));
      }
      final plans = <Plan>[];
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        plans.addAll(snapshot.docs.map((doc) => Plan.fromJson(doc.data())));
      }
      return plans;
    } catch (e) {
      debugPrint('Error getting plans by IDs: $e');
      return [];
    }
  }

  /// Create a new plan (legacy format - also creates subcollections)
  Future<String> createPlan(Plan plan) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final planWithId = plan.copyWith(id: docRef.id);
      
      // Use a batch for atomic writes
      final batch = _firestore.batch();
      
      // Write main plan document
      batch.set(docRef, planWithId.toJson());
      
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

  /// Update a plan (legacy format)
  Future<void> updatePlan(Plan plan) async {
    try {
      await _firestore.collection(_collection).doc(plan.id).update(
        plan.copyWith(updatedAt: DateTime.now()).toJson(),
      );
    } catch (e) {
      debugPrint('Error updating plan: $e');
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
        
        versions.add(versionData.toPlanVersion(days));
      }
      
      // Build Plan from metadata + loaded versions
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
      );
    } catch (e) {
      debugPrint('Error loading full plan: $e');
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
      
      return versionDoc.toPlanVersion(dayItineraries);
    } catch (e) {
      debugPrint('Error loading full version: $e');
      return null;
    }
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
}
